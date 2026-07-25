**Runner environment preparation**

This document explains the intent and usage of `scripts/prepare-runner-environment.ps1`.

Purpose
- Create host directories for Docker and Hyper-V VM storage
- Enable Hyper-V feature when missing (requires reboot)
- Configure Docker data-root for Docker Engine (if present)
- Create a Hyper-V internal switch and NAT for VM networking
- Add a dedicated service account to `docker-users` and `Hyper-V Administrators` (if a service account is supplied)
- Provide cleanup commands for test artifacts

Usage
Run the script as Administrator on the runner host:

```powershell
# example: set Docker data and VM paths, create switch and configure service account
.
\scripts\prepare-runner-environment.ps1 -DockerDataPath D:\DockerData -HyperVVMPath E:\HyperV -VMSwitchName SQLServerAnalyzeSwitch -ServiceAccount ".\\RunnerSvc"
```

Notes and caveats
- Docker Desktop: the script configures `C:\ProgramData\Docker\config\daemon.json` only when a Windows Docker service named `docker` exists (Docker Engine). Docker Desktop on Windows uses WSL2 and its data-root is configured differently; you may need to adjust Docker Desktop settings manually.
- Hyper-V enablement requires a reboot. The script will enable the feature but will not reboot the host.
- Creating an external VMSwitch requires selecting a network adapter; the script creates an internal switch by default and a NAT mapping for basic network access.
- Granting 'Log on as a service' and secure password management must be done according to your organisation policies; the script demonstrates group membership changes but does not manage Log on as a service rights.
- Review and adapt the script to match your storage layout and security requirements.

Recommended follow-up tasks
- Create a documented service account with `Log on as a service` and add to the appropriate groups.
- Configure Docker Desktop data-root if using Docker Desktop and WSL2.
- Validate Hyper-V networking by creating a small test VM and verifying it gets network access through the NAT.

Files
- `scripts/prepare-runner-environment.ps1` — automated preparation script (requires Administrator)
- `Documentation/Lab/Self_Hosted_Windows_Runner_Setup.md` — main runner setup how-to (updated with service troubleshooting)
- `Documentation/Lab/Runner_Environment_Prepare.md` — this document
