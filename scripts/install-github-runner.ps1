<#
Install GitHub Actions runner under C:\actions-runner\SQL_Server_Analyze
Usage (run as Administrator):
  powershell -ExecutionPolicy Bypass -File .\install-github-runner.ps1 -Token <REGISTRATION_TOKEN>

This script downloads the runner ZIP, validates checksum, and extracts it.
It DOES NOT register the runner automatically unless you pass the -AutoConfigure switch
and provide a token. The registration command is shown at the end.
#>
param(
    [string]$Token = '',
    [switch]$AutoConfigure
)

function Assert-Admin {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error 'This script must be run as Administrator.'
        exit 1
    }
}

Assert-Admin

$runnerVersion = '2.336.0'
$zipName = "actions-runner-win-x64-$runnerVersion.zip"
$downloadUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/$zipName"
$expectedSha256 = 'D59123A43003E357B0805B5D0F611D0BD2F65AB67D51BD070DD4E7A0F685C162'

$base = 'C:\actions-runner'
$dest = Join-Path $base 'SQL_Server_Analyze'

Write-Host "Creating base dirs: $base and $dest"
New-Item -Path $base -ItemType Directory -Force | Out-Null
New-Item -Path $dest -ItemType Directory -Force | Out-Null

$zipPath = Join-Path $base $zipName

Write-Host "Downloading runner $runnerVersion to $zipPath"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

Write-Host 'Validating checksum (SHA256)'
$actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToUpper()
if ($actual -ne $expectedSha256) {
    Write-Error "Checksum mismatch. Expected $expectedSha256 but got $actual"
    exit 2
}

Write-Host 'Extracting archive'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $dest)

Write-Host "Extraction complete. Runner files are in: $dest"

# Show next steps
$cfgCmd = ".\config.cmd --url https://github.com/gecompat/SQL_Server_Analyze --token <TOKEN>"
$svcNote = "To install as service: svc install (run from runner directory) or use .\bin\RunnerService.exe install"

Write-Host "\nNext steps:"
Write-Host "  1) If you have a registration token, run (from $dest):"
Write-Host "     $cfgCmd" -ForegroundColor Yellow
Write-Host "  2) To start the runner interactively: .\run.cmd"
Write-Host "  3) To install as Windows service (recommended for production test runners):"
Write-Host "     $svcNote" -ForegroundColor Yellow

if ($AutoConfigure) {
    if (-not $Token) { Write-Error 'AutoConfigure requested but no Token provided.'; exit 3 }
    Push-Location $dest
    Write-Host 'Configuring runner (non-interactive)'
    & .\config.cmd --url https://github.com/gecompat/SQL_Server_Analyze --token $Token
    Write-Host 'Configuration command completed. Review output above for errors.'
    Pop-Location
}

Write-Host 'Done.'
