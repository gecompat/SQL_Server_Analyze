# Self-hosted Windows Runner Setup for SQL_Server_Analyze

## Purpose

This document describes how to prepare a dedicated Windows machine as a repository-level GitHub Actions self-hosted runner for SQL Server Analyze tests.

The runner is intended for controlled laboratory execution of:

- Docker based SQL Server test environments
- Hyper-V based test environments
- SQL Server version validation
- framework installation and validation workflows

The runner must only be registered for the repository `gecompat/SQL_Server_Analyze`.

---

## Security model

A self-hosted runner executes repository workflows with the permissions of the runner service account.

Recommended rules:

- Use dedicated test hardware.
- Use a dedicated Windows service account.
- Do not store credentials in the repository.
- Do not execute untrusted pull requests with administrator privileges.
- Keep runner access restricted to the intended repository.

---

## Recommended Windows prerequisites

Minimum:

- Windows 11 Pro or Windows Server
- 64-bit operating system
- Hardware virtualization enabled in BIOS/UEFI
- PowerShell 7 recommended
- Git installed
- Python installed
- Docker Desktop or Docker Engine available
- Optional: Hyper-V enabled

Recommended resources for SQL Server version testing:

- 8+ CPU cores
- 64 GB RAM or more
- SSD storage

---

## Preflight validation

Run the following checks before installation.

### Windows version

Do not rely on the legacy `WindowsVersion` property. Use the current registry values:

```powershell
Get-ItemProperty `
"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" |
Select-Object ProductName, DisplayVersion, CurrentBuild, UBR
```

The build number should be compatible with Windows 11 or a supported Windows Server version.

### CPU and virtualization

```powershell
Get-CimInstance Win32_Processor |
Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, VirtualizationFirmwareEnabled
```

### Memory

```powershell
"{0:N1} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
```

### Hyper-V feature

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

### WSL2

```powershell
wsl --version
```

### Docker

```powershell
docker --version
docker info
docker compose version
```

Functional test:

```powershell
docker run --rm hello-world
```

### Git

```powershell
git --version
```

### Python

```powershell
python --version
```

---

## Storage recommendation

Separate operating system, container data and virtual machines where possible.

Example:

```
C:
  Windows
  GitHub Runner
  Development tools

D:
  Docker data
  Container images
  SQL Server container data

E:
  Hyper-V virtual machines
  VM test data
```

---

## Install GitHub Actions Runner

In the repository:

```
Settings
  -> Actions
  -> Runners
  -> New self-hosted runner
```

Select:

```
Windows
x64
```

Create a dedicated directory, for example:

```
C:\GitHubRunner\SQL_Server_Analyze
```

Download and configure the runner using the commands provided by GitHub.

Example registration pattern:

```powershell
config.cmd `
  --url https://github.com/gecompat/SQL_Server_Analyze `
  --token <registration-token>
```

Use repository-level registration.

Recommended labels:

```
self-hosted
windows
sql-test
docker
hyperv
```

---

## Run runner as Windows service

Install:

```powershell
svc install
```

Start:

```powershell
svc start
```

The service should run under a dedicated service account.

Required permissions depend on enabled test profiles:

Docker:

- membership in `docker-users`

Hyper-V:

- membership in `Hyper-V Administrators`

Advanced SQL Server lifecycle tests may require local administrator permissions.

---

## Docker test profile

Recommended default profile:

```
Windows
 |
 Docker Desktop
 |
 WSL2 backend
 |
 SQL Server containers
```

Example SQL Server container validation:

```powershell
docker run --rm hello-world
```

SQL Server version-specific tests should use separate ports and isolated container names.

---

## Hyper-V test profile

Hyper-V can be enabled together with Docker Desktop.

Typical architecture:

```
Windows Host
 |
 Hyper-V
 |
 Linux VM
 |
 Docker Engine
 |
 SQL Server containers
```

This allows comparison between:

- Docker Desktop based execution
- native VM based execution

Both profiles should be tested separately to keep results reproducible.

---

## Validation workflow

After installation, execute a repository workflow that verifies:

- runner availability
- Docker availability
- SQL Server container startup
- framework installation
- cleanup behaviour

A successful runner setup is indicated by:

```
Runner: Online
Docker: Ready
Hyper-V: Ready (if enabled)
SQL Test Environment: Ready
```

---

## Troubleshooting

### Docker command not available

Check:

```powershell
Get-Command docker
```

Verify the runner service account has Docker permissions.

### Hyper-V unavailable

Check:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

Verify BIOS virtualization support.

### Windows version detection differences

Modern Windows versions may expose inconsistent legacy fields. Prefer build number and `DisplayVersion` over `WindowsVersion`.

### Service fails to start (Win32Exception 1068)

Symptom: the runner service is installed but fails to start with an error similar to:

```
System.ComponentModel.Win32Exception (0x80004005): Der Abhängigkeitsdienst oder die Abhängigkeitsgruppe konnte nicht gestartet werden.
```

Cause: In our lab a freshly installed runner service used the `NetworkService` account by default and could not start due to permission/Logon issues for dependent operations (for example access to Docker, Hyper-V or service startup privileges). When the service is started interactively via `run.cmd` the runner works, indicating the runtime itself is healthy — the issue is the Windows service account or a missing dependency.

Quick checks and remediation (run in an elevated PowerShell on the runner host):

```powershell
# Inspect service configuration and dependencies
sc.exe qc actions.runner.<YOUR_INSTANCE_NAME>
reg query "HKLM\SYSTEM\CurrentControlSet\Services\actions.runner.<YOUR_INSTANCE_NAME>" /v DependOnService

# Try starting the service (may fail if current account lacks rights)
sc.exe start "actions.runner.<YOUR_INSTANCE_NAME>"

# If start fails with access denied or dependency errors, try switching to LocalSystem to verify account problems
sc.exe config "actions.runner.<YOUR_INSTANCE_NAME>" obj= LocalSystem
sc.exe start "actions.runner.<YOUR_INSTANCE_NAME>"
```

If the service starts successfully as `LocalSystem`, create a dedicated service account for production usage and grant it the following:

- `Log on as a service` right
- Membership in `docker-users` if Docker access is required
- Membership in `Hyper-V Administrators` if Hyper-V management is required

Example: create and configure a dedicated account and assign rights (elevated PowerShell):

```powershell
# Create local service account (replace name and password)
# New-LocalUser -Name RunnerSvc -Password (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -Description "GitHub Actions runner service account"

# Grant 'Log on as a service' via ntrights (or local security policy / GPO)
# ntrights.exe +r SeServiceLogonRight -u RunnerSvc

# Add to docker-users and Hyper-V Administrators
# Add-LocalGroupMember -Group "docker-users" -Member RunnerSvc
# Add-LocalGroupMember -Group "Hyper-V Administrators" -Member RunnerSvc

# Configure service to run under the dedicated account
sc.exe config "actions.runner.<YOUR_INSTANCE_NAME>" obj= ".\\RunnerSvc" password= "<secure-password>"
sc.exe start "actions.runner.<YOUR_INSTANCE_NAME>"
```

Notes:
- Use a secure password and follow your organisation's account lifecycle and auditing rules.
- If you cannot change the service account, running the runner interactively via `run.cmd` is an acceptable fallback for ad-hoc or test runs.
- Document the chosen service account and required group memberships alongside the runner installation artifacts so future reinstallations reproduce the working configuration.

---

## References

- GitHub Actions self-hosted runners: https://docs.github.com/actions/hosting-your-own-runners
- Docker Desktop documentation: https://docs.docker.com/desktop/
- Microsoft Hyper-V documentation: https://learn.microsoft.com/windows-server/virtualization/hyper-v/
