# Docker/Podman quick-test system

This directory contains the container-only SQL Server quick-test system. The
public entrypoints are:

- `Lab/Install-Lab.ps1` for `Preflight`, `Install`, `Status`, and `Destroy`;
- `Lab/Uninstall-Lab.ps1` for confirmed removal of one exact quick-test scope.

The first executable runtime delivery is limited to native x86-64 Linux. It
uses the shared Compose core for Docker or Podman and supports SQL Server 2019,
2022, and 2025 independently or together. It does not replace Windows, WSFC,
FCI, or hardware-specific test environments.

A green static or synthetic lifecycle test is not a native container-host run.
External Docker and Podman evidence remains `NOT_EXECUTED` until a suitable host
is available.

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

Preflight is read-only. It checks operating system, architecture, runtime,
Compose, ports, memory, writable storage ancestry, generic scope conflicts,
image availability, EULA acceptance, and credential complexity. The result is
`READY` or `PREFLIGHT_FAILED` with structured reason codes and
`MutationBoundary = READ_ONLY_PREFLIGHT`.

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

For automation, the credential may be provided through a named process
environment variable using `-SecretEnvironmentVariable`. The value is converted
to a read-only `SecureString` without using a plain-text conversion cmdlet.

## Install

Install always runs the same read-only Preflight before the first mutation.
Selected versions are started sequentially to reduce peak host pressure. Each
container must become healthy, answer a SQL query, and report the expected
major version before the next selected version is started.

```powershell
$credentialInput = Read-Host 'SQL credential' -AsSecureString
./Lab/Install-Lab.ps1 `
  -Action Install `
  -Runtime DOCKER `
  -SqlVersions 2022,2025 `
  -Ports @{ 2022 = 14332; 2025 = 14335 } `
  -AdminLogin ExampleSqlAdmin `
  -AdminSecret $credentialInput `
  -ResourceProfile SMALL `
  -PersistenceMode TEMPORARY `
  -AcceptEula `
  -NonInteractive
```

Use `-Runtime PODMAN` for the Podman lane. Both lanes use the same Compose core
and different resource-limit overrides.

`-GenerateSecret` creates an ephemeral credential. For `Install`, that generated
value is stored only under the ignored local `.secrets/quick-test/<scope>` path
with owner-only file permissions. The command returns the local file path, not
the value. User-supplied credentials are not persisted.

`-InstallFramework` invokes the existing canonical standalone framework builder
and installs `SQL_Server_Analyze` into the synthetic database `LabAnalyze` after
each selected SQL Server instance becomes ready.

## Local state and ownership

Before the first Compose mutation, Install writes a local recovery state under
`.state/quick-test/<scope>` and creates an owner marker containing the synthetic
run ID. Data is stored under `.artifacts/quick-test/<scope>` by default.

The state stores only local runtime metadata such as:

- generic scope and run ID;
- Docker or Podman;
- selected SQL versions, ports, and resource profile;
- full container and network object IDs;
- owner-bound local roots;
- framework-installation status.

It does not contain the SQL credential or a connection string containing a
credential.

## Status

```powershell
./Lab/Install-Lab.ps1 `
  -Action Status `
  -ScopeName sql-analyze-quicktest
```

Status reads the owner-bound local state and verifies each stored full
container ID. It reports runtime state, health state, port, SQL version, and
run-label ownership. A container is `Ready` only when it is running, healthy,
and still owned by the saved run ID.

## Destroy and uninstall

Destroy requires confirmation unless `-Force` is supplied:

```powershell
./Lab/Install-Lab.ps1 `
  -Action Destroy `
  -ScopeName sql-analyze-quicktest
```

The dedicated wrapper performs the same operation:

```powershell
./Lab/Uninstall-Lab.ps1 `
  -ScopeName sql-analyze-quicktest
```

For documented unattended cleanup:

```powershell
./Lab/Uninstall-Lab.ps1 `
  -ScopeName sql-analyze-quicktest `
  -RemoveData `
  -Force
```

Cleanup discovers resources through the exact run-ID label, resolves canonical
full object IDs, verifies ownership again, and removes only those exact
containers and networks. It never performs a global prune or name-only delete.
Local state, generated-credential, and data directories are removed only when
their owner marker matches and their canonical path remains below the saved
approved root.

`TEMPORARY` data is removed by Destroy. `PERSISTENT` data is retained unless
`-RemoveData` is specified.

## Connection information

A successful Install returns one entry per SQL Server version with:

- `localhost` and the configured host port;
- the generic login name;
- a `sqlcmd` command without an embedded credential;
- a connection-string template without an embedded credential;
- `LabAnalyze` when framework installation was requested.

The credential is never printed again.

## Current boundary

The following remain open after this delivery:

- Start, Stop, Restart, and Reset;
- a separate UpdateFramework action;
- Down while preserving persistent data and state;
- native Docker and Podman execution evidence;
- end-to-end SQL Server 2019, 2022, and 2025 host evidence.
