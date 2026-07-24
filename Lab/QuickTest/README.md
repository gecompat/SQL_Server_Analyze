# Docker and Podman quick-test core

This directory contains the PowerShell 7 implementation used by
`Lab/Install-Lab.ps1` and `Lab/Uninstall-Lab.ps1`.

The implementation is restricted to clearly synthetic SQL Server Developer
Edition test instances on native x86-64 Linux. Docker and Podman use the same
public lifecycle contract and separate Compose overrides. Repository CI
validates parser, policy, Compose, privacy, cleanup, and output contracts; it
does not claim a real container runtime execution.

Secrets enter the Compose process only through process-scoped environment
pass-through. Generated secrets may be written only below the ignored
`Lab/.secrets/quick-test` scope with restrictive local file permissions. A
secret value is never included in a generated Compose file, state JSON,
connection string, or console output.

State records full runtime object IDs. Status and Destroy revalidate the saved
run-ID labels before trusting those IDs. Local data and secret directories also
require exact owner markers and path containment before recursive removal.
The implementation never uses broad prune operations or name-only deletion.

The initial vertical slice implements `Preflight`, `Install`, `Status`, and
`Destroy`. The next lifecycle slice will add `Start`, `Stop`, `Restart`,
`Reset`, and `UpdateFramework`. External Docker and Podman evidence remains
`NOT_EXECUTED` until an approved host is available.
