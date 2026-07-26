function Get-SqlConfigurationFile {
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][string] $SaPassword
    )

    $instanceDir = 'C:\Program Files\Microsoft SQL Server'
    $content = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE,FULLTEXT,CONN
INSTANCENAME="MSSQLSERVER"
INSTANCEDIR="$instanceDir"
SQLSYSADMINACCOUNTS="BUILTIN\Administrators"
SECURITYMODE="SQL"
SAPWD="$SaPassword"
SQLCOLLATION="SQL_Latin1_General_CP1_CS_AS"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCSTARTUPTYPE="Automatic"
BROWSERSVCSTARTUPTYPE="Disabled"
TCPENABLED=1
NPENABLED=0
IACCEPTSQLSERVERLICENSETERMS=1
SQLSVCINSTANTFILEINIT="True"
SQUPDATESOURCE="MU"
UPDATEENABLED="False"
QUIET="True"
QS="True"
"@
    return $content
}

function Install-SqlServerInVm {
    param(
        [Parameter(Mandatory)][string] $VmName,
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][string] $MediaPath,
        [Parameter(Mandatory)][string] $SaPassword,
        [Parameter(Mandatory)][pscredential] $Credential
    )

    Write-Section "SQL Server $Version Installation in '$VmName'"

    # ConfigurationFile erzeugen und in VM kopieren
    $configContent = Get-SqlConfigurationFile -Version $Version -SaPassword $SaPassword
    $tempConfig = Join-Path $env:TEMP "sql_config_$Version.ini"
    [IO.File]::WriteAllText($tempConfig, $configContent, [Text.Encoding]::UTF8)

    try {
        # Datei in VM kopieren via Guest Services
        $vmConfigPath = 'C:\Temp\sql_config.ini'
        Invoke-VmPowerShell -VmName $VmName -Credential $Credential -ScriptBlock {
            if (-not (Test-Path 'C:\Temp')) { New-Item -Path 'C:\Temp' -ItemType Directory -Force | Out-Null }
        }
        Copy-VMFile -Name $VmName -SourcePath $tempConfig -DestinationPath $vmConfigPath `
            -FileSource Host -CreateFullPath -Force

        # ISO in VM mounten und Setup starten
        Invoke-VmPowerShell -VmName $VmName -Credential $Credential -ScriptBlock {
            param($IsoPath, $ConfigPath)

            # ISO mounten
            $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
            $driveLetter = ($mountResult | Get-Volume).DriveLetter
            $setupPath = "${driveLetter}:\setup.exe"

            if (-not (Test-Path $setupPath)) {
                Dismount-DiskImage -ImagePath $IsoPath
                throw "setup.exe nicht gefunden auf $setupPath"
            }

            Write-Host "Starte SQL Server Setup von ${driveLetter}:\..."
            $process = Start-Process -FilePath $setupPath `
                -ArgumentList "/ConfigurationFile=`"$ConfigPath`"" `
                -Wait -PassThru -NoNewWindow

            Dismount-DiskImage -ImagePath $IsoPath

            if ($process.ExitCode -ne 0) {
                $summaryLog = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\Log' `
                    -Filter 'Summary.txt' -Recurse -ErrorAction SilentlyContinue | Select-Object -Last 1
                if ($summaryLog) {
                    $lastLines = Get-Content $summaryLog.FullName -Tail 30
                    Write-Host ($lastLines -join "`n")
                }
                throw "SQL Server Setup fehlgeschlagen (Exit Code: $($process.ExitCode))."
            }
            Write-Host 'SQL Server Setup erfolgreich.'
        } -ArgumentList @($MediaPath, $vmConfigPath)

        # Query Store aktivieren
        Write-Host 'Aktiviere Query Store auf master...'
        Invoke-VmPowerShell -VmName $VmName -Credential $Credential -ScriptBlock {
            param($Password)
            $query = "ALTER DATABASE [master] SET QUERY_STORE = ON;"
            Invoke-Sqlcmd -ServerInstance 'localhost' -Username 'sa' -Password $Password `
                -Query $query -TrustServerCertificate -ErrorAction SilentlyContinue
        } -ArgumentList @($SaPassword)
    }
    finally {
        if (Test-Path -LiteralPath $tempConfig) {
            Remove-Item -LiteralPath $tempConfig -Force
        }
    }
}

function Install-FrameworkInVm {
    param(
        [Parameter(Mandatory)][string] $VmName,
        [Parameter(Mandatory)][string] $SaPassword,
        [Parameter(Mandatory)][pscredential] $Credential
    )

    Write-Section "Framework-Installation in '$VmName'"

    # Standalone-Installer erzeugen
    $buildScript = Join-Path $script:RepositoryRoot 'Code/Install/Build-StandaloneInstaller.ps1'
    $generatedInstaller = Join-Path $env:TEMP 'Install_All.generated.sql'
    & pwsh -NoLogo -NoProfile -File $buildScript -OutputPath $generatedInstaller
    if ($LASTEXITCODE -ne 0) {
        throw 'Standalone-Installer-Erzeugung fehlgeschlagen.'
    }

    # Datenbanknamen ersetzen
    $content = [IO.File]::ReadAllText($generatedInstaller, [Text.Encoding]::UTF8)
    $content = $content.Replace('[DeineDatenbank]', '[LabAnalyze]')
    [IO.File]::WriteAllText($generatedInstaller, $content, [Text.Encoding]::UTF8)

    # In VM kopieren
    $vmInstallerPath = 'C:\Temp\Install_All.sql'
    Copy-VMFile -Name $VmName -SourcePath $generatedInstaller -DestinationPath $vmInstallerPath `
        -FileSource Host -CreateFullPath -Force

    # Datenbank erstellen und Installer ausführen
    Invoke-VmPowerShell -VmName $VmName -Credential $Credential -ScriptBlock {
        param($Password, $InstallerPath)

        # LabAnalyze erstellen
        $createDb = @"
IF DB_ID(N'LabAnalyze') IS NULL
BEGIN
    CREATE DATABASE [LabAnalyze] COLLATE SQL_Latin1_General_CP1_CS_AS;
    ALTER DATABASE [LabAnalyze] SET QUERY_STORE = ON;
END
"@
        Invoke-Sqlcmd -ServerInstance 'localhost' -Username 'sa' -Password $Password `
            -Query $createDb -TrustServerCertificate

        # Framework installieren
        Write-Host 'Installiere Framework in LabAnalyze...'
        Invoke-Sqlcmd -ServerInstance 'localhost' -Username 'sa' -Password $Password `
            -InputFile $InstallerPath -TrustServerCertificate -ErrorAction Stop

        # Verifizierung
        $verify = Invoke-Sqlcmd -ServerInstance 'localhost' -Username 'sa' -Password $Password `
            -Database 'LabAnalyze' -TrustServerCertificate `
            -Query "SELECT COUNT(*) AS ObjCount FROM sys.objects WHERE schema_id = SCHEMA_ID(N'monitor');"
        if ($verify.ObjCount -lt 100) {
            throw "Framework-Verifizierung fehlgeschlagen: Nur $($verify.ObjCount) Objekte im Schema monitor."
        }
        Write-Host "Framework installiert: $($verify.ObjCount) Objekte in [monitor]."
    } -ArgumentList @($SaPassword, $vmInstallerPath)

    # Aufräumen
    Remove-Item -LiteralPath $generatedInstaller -Force -ErrorAction SilentlyContinue
    Write-Host 'FRAMEWORK_READY.'
}
