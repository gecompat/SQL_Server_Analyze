# Docker/Podman quick-test Preflight

This directory contains the read-only Preflight implementation for the
container-only SQL Server quick-test system. It does not create directories,
containers, networks, volumes, configuration files, or runtime state.

The public entrypoint is `Lab/Install-Lab.ps1`. In this delivery its only
supported action is `Preflight`. Lifecycle actions are intentionally deferred
to a separate implementation step.

## Interactive Preflight

```powershell
./Lab/Install-Lab.ps1
```

The script asks for:

- Docker or Podman;
- one or more SQL Server versions from 2019, 2022, and 2025;
- one host port per selected version;
- a generic administrative SQL login;
- a masked SQL credential or ephemeral generated credential;
- resource profile `SMALL`, `MEDIUM`, or `LARGE`;
- persistence mode `PERSISTENT` or `TEMPORARY`;
- local data root;
- SQL Server container EULA acceptance.

The credential is held only as a `SecureString` and is never written to
repository files, Compose files, state, or console output.

## Non-interactive Preflight

```powershell
$credentialInput = Read-Host 'SQL credential' -AsSecureString
./Lab/Install-Lab.ps1 `
  -Action Preflight `
  -Runtime DOCKER `
  -SqlVersions 2019,2022,2025 `
  -Ports @{ 2019 = 14331; 2022 = 14332; 2025 = 14335 } `
  -AdminLogin ExampleSqlAdmin `
  -AdminSecret $credentialInput `
  -ResourceProfile SMALL `
  -PersistenceMode TEMPORARY `
  -AcceptEula `
  -NonInteractive
```

For automation, a caller may provide an environment-variable name through
`-SecretEnvironmentVariable` or request `-GenerateSecret`. The value itself is
not returned. Generated-credential persistence belongs to the later lifecycle
implementation and is not performed by Preflight.

## Checks

Preflight returns `READY` or `PREFLIGHT_FAILED` with structured reason codes.
It checks:

- native Linux and x86-64 architecture;
- selected runtime and Compose command availability;
- SQL Server version selection;
- unique, currently available host ports;
- profile-based memory reserve;
- an existing writable ancestor for the requested data root;
- generic scope conflicts through read-only runtime listing;
- SQL Server image availability unless explicitly skipped;
- EULA acceptance;
- SQL credential complexity.

The output property `MutationBoundary` is always
`READ_ONLY_PREFLIGHT`. Runtime values may be returned to the local caller for
diagnosis, but no such output is versioned or published automatically.

## Current boundary

The following remain unimplemented in this delivery:

- Install or Up;
- Start, Stop, Restart, and Reset;
- framework installation and UpdateFramework;
- Status, Down, and Destroy;
- native Docker and Podman evidence.

The Compose contract foundation is already versioned under `Lab/Containers`.
A green static or synthetic Preflight test is not a real container-host run.
