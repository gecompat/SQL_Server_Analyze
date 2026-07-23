function Test-LabSecretAvailability {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $SecretPolicy
    )

    $missingNames = [Collections.Generic.List[string]]::new()
    switch ($SecretPolicy.Provider) {
        'NONE' {
            foreach ($name in $SecretPolicy.RequiredSecretNames) {
                $missingNames.Add([string] $name)
            }
        }
        'ENVIRONMENT' {
            foreach ($name in $SecretPolicy.RequiredSecretNames) {
                $variableName = "LAB001_SECRET_$name"
                if ([string]::IsNullOrEmpty(
                        [Environment]::GetEnvironmentVariable($variableName)
                    )) {
                    $missingNames.Add([string] $name)
                }
            }
        }
        'SECRET_MANAGEMENT' {
            $getSecretInfo = Get-Command Get-SecretInfo -ErrorAction SilentlyContinue
            if ($null -eq $getSecretInfo) {
                foreach ($name in $SecretPolicy.RequiredSecretNames) {
                    $missingNames.Add([string] $name)
                }
            }
            else {
                foreach ($name in $SecretPolicy.RequiredSecretNames) {
                    $secretInfo = Get-SecretInfo -Name $name -ErrorAction SilentlyContinue
                    if ($null -eq $secretInfo) {
                        $missingNames.Add([string] $name)
                    }
                }
            }
        }
        'INTERACTIVE' {
            if (-not $SecretPolicy.AllowInteractive) {
                foreach ($name in $SecretPolicy.RequiredSecretNames) {
                    $missingNames.Add([string] $name)
                }
            }
        }
    }

    return [pscustomobject] @{
        Provider = [string] $SecretPolicy.Provider
        IsAvailable = ($missingNames.Count -eq 0)
        MissingLogicalSecretNames = @($missingNames)
    }
}

function Get-LabSecretValue {
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Z][A-Z0-9_]{0,63}$')]
        [string] $LogicalSecretName,

        [Parameter(Mandatory)]
        [pscustomobject] $SecretPolicy
    )

    switch ($SecretPolicy.Provider) {
        'ENVIRONMENT' {
            $value = [Environment]::GetEnvironmentVariable(
                "LAB001_SECRET_$LogicalSecretName"
            )
            if ([string]::IsNullOrEmpty($value)) {
                throw 'Required environment-backed LAB-001 secret is unavailable.'
            }
            return ConvertTo-SecureString -String $value -AsPlainText -Force
        }
        'SECRET_MANAGEMENT' {
            $value = Get-Secret -Name $LogicalSecretName -ErrorAction Stop
            if ($value -is [securestring]) {
                return $value
            }
            return ConvertTo-SecureString -String ([string] $value) -AsPlainText -Force
        }
        'INTERACTIVE' {
            if (-not $SecretPolicy.AllowInteractive) {
                throw 'Interactive secret input is not enabled.'
            }
            return Read-Host `
                -Prompt "Enter synthetic LAB-001 secret $LogicalSecretName" `
                -AsSecureString
        }
        default {
            throw 'No LAB-001 secret provider is configured.'
        }
    }
}

function New-LabCredential {
    [CmdletBinding()]
    [OutputType([pscredential])]
    param(
        [Parameter(Mandatory)]
        [string] $UserName,

        [Parameter(Mandatory)]
        [string] $LogicalSecretName,

        [Parameter(Mandatory)]
        [pscustomobject] $SecretPolicy
    )

    $secureValue = Get-LabSecretValue `
        -LogicalSecretName $LogicalSecretName `
        -SecretPolicy $SecretPolicy
    return [pscredential]::new($UserName, $secureValue)
}
