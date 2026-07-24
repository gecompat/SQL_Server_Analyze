# Docker/Podman quick-test system

This directory contains the container-only SQL Server quick-test system. Its
binding requirements and acceptance boundaries are documented in the
[Docker/Podman quick-test system requirements](../../Documentation/Architecture/Docker_Podman_Quick_Test_System_Requirements.md).
The public entrypoints are:

- `Lab/Install-Lab.ps1` for `Preflight`, `Install`, `Status`, and `Destroy`;
- `Lab/Uninstall-Lab.ps1` for confirmed destruction of one exact quick-test scope.

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
- persistence intent `PERSISTENT` or `TEMPORARY`;
- local data root;
- SQL Server container EULA acceptance.

Preflight is read-only. It checks operating system, architecture, runtime,
Compose, ports, memory, writable storage ancestry, generic scope conflicts,
image availability, EULA acceptance, and credential complexity. The result is
`READY` or `PREFLIGHT_FAILED` with structured reason codes and
`MutationBoundary = READ_ONLY_PREFLIGHT`.

## Non-interactive Preflight

```powershell
$adminCredential = Read-Host 'SQL credential' -AsSecureString
./Lab/Install-Lab.ps1 `
  -Action Preflight `
  -Runtime DOCKER `
  -SqlVersions 2019,2022,2025 `
  -Ports @{ 2019 = 14331; 2022 = 14332; 2025 = 14335 } `
  -AdminLogin ExampleSqlAdmin `
  -AdminSecret $adminCredential `
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
$adminCredential = Read-Host 'SQL credential' -AsSecureString
./Lab/Install-Lab.ps1 `
  -Action Install `
  -Runtime DOCKER `
  -SqlVersions 2022,2025 `
  -Ports @{ 2022 = 14332; 2025 = 14335 } `
  -AdminLogin ExampleSqlAdmin `
  -AdminSecret $adminCredential `
  -ResourceProfile SMALL `
  -PersistenceMode TEMPORARY `
  -AcceptEula `
  -NonInteractive
```

Use `-Runtime PODMAN` for the Podman lane. Both lanes use the same Compose core
and separate resource-limit overrides.

`-GenerateSecret` creates an ephemeral generated credential. For `Install`, that
value is stored only under the ignored local `.secrets/quick-test/<scope>` path
with owner-only directory and file permissions. The command returns the local
file path, not the value. User-supplied credentials are not persisted.

`-InstallFramework` invokes the existing canonical standalone framework builder,
installs `SQL_Server_Analyze` into the synthetic database `LabAnalyze`, and
verifies that the database and `monitor` schema exist. Failure of this
verification fails the corresponding Install action.

## Resource and load boundary

The `SMALL` profile is the default. CPU and memory limits are passed to every
selected container. Install starts selected versions sequentially; it does not
start all versions concurrently. The lifecycle never changes global Docker or
Podman settings, never raises host limits, and never touches unrelated runtime
objects.

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
credential. Install refuses pre-existing unmarked local scope directories; it
does not adopt or overwrite them.

If Install fails after a runtime mutation, discovered run-labeled objects are
resolved to full IDs, recorded in the local recovery state, and removed only by
those full IDs. Remaining objects are never selected by name or by a broad prune
operation.

## Status

```powershell
./Lab/Install-Lab.ps1 `
  -Action Status `
  -ScopeName sql-analyze-quicktest
```

Status reads the owner-bound local state and validates each stored full
container ID. It reports runtime state, health state, port, SQL version, and
run-label ownership. A container is `Ready` only when it is running, healthy,
and still owned by the saved run ID.

Status does not create, start, stop, or remove runtime objects.

## Destroy and uninstall

`Destroy` means complete destruction of the selected quick-test scope. It
removes its registered containers, registered network, generated local
credential, state, and all marked local data. It requires confirmation unless
`-Force` is supplied.

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

For documented unattended destruction:

```powershell
./Lab/Uninstall-Lab.ps1 `
  -ScopeName sql-analyze-quicktest `
  -Force
```

Destroy uses the full object IDs registered in local state and verifies current
run-label ownership before deletion. Run-labeled objects that are not registered
in state cause Destroy to stop instead of widening its deletion scope. It never
performs a global prune or a name-only delete.

Local state, generated-credential, and data directories are removed only when
their owner marker matches and their canonical path remains below the saved
approved root.

`PERSISTENT` currently describes the intended behavior of the future `Down`
action. It does not weaken `Destroy`: Destroy always removes the complete scope.

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
