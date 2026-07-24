# Docker and Podman quick-test Preflight

The quick-test interface is the read-only second delivery of
`LAB-QUICKTEST-001`. Its contract status is `IMPLEMENTED_AUTOMATED_GATE`.
Real Docker and Podman execution remains `NOT_EXECUTED` because no approved
native x86-64 Linux host is currently available.

## Entry point

```powershell
./Lab/Install-Lab.ps1
```

Interactive mode asks for:

- Docker or Podman;
- SQL Server 2019, 2022, and/or 2025;
- one host port per selected version;
- the administrative SQL login;
- a masked SQL secret;
- `SMALL`, `MEDIUM`, or `LARGE` resource profile;
- `PERSISTENT` or `TEMPORARY` data intent;
- optional framework installation;
- SQL Server container EULA acceptance.

The default ports are 14331, 14332, and 14335. The default login is the clearly
synthetic `ExampleSqlAdmin`.

## Non-interactive example

The secret value is supplied outside the command through `QTLAB_SQL_SECRET`.
It must not be stored in scripts, argument lists, configuration files, or shell
history.

```powershell
./Lab/Install-Lab.ps1 `
    -Runtime DOCKER `
    -SqlVersions 2019,2022,2025 `
    -Ports @{ 2019 = 14331; 2022 = 14332; 2025 = 14335 } `
    -AdminLogin ExampleSqlAdmin `
    -SecretEnvironmentVariable QTLAB_SQL_SECRET `
    -ResourceProfile SMALL `
    -PersistenceMode TEMPORARY `
    -InstallFramework `
    -AcceptEula `
    -NonInteractive
```

Use `-Runtime PODMAN` for the Podman plan. `-GenerateSecret` validates the
random-credential contract in memory; this delivery does not persist or print
the generated value.

## Read-only checks

Preflight evaluates:

- native Linux and x86-64 platform boundary;
- selected Docker or Podman executable and Compose provider;
- SQL Server version selection;
- duplicate, invalid, and currently occupied host ports;
- available RAM versus selected versions and resource profile;
- the nearest existing parent of the configured data root;
- SQL secret complexity without exposing the value;
- EULA acceptance;
- Microsoft image availability through read-only manifest inspection, unless
  explicitly skipped.

The result contains `Checks`, `BlockerReasonCodes`, the effective plan,
`MutationPerformed = false`, and
`NextAction = INSTALL_LIFECYCLE_NOT_IMPLEMENTED`.

This delivery does not run `compose up`, create or remove containers or
networks, write credentials, create data directories, install the framework, or
publish runtime evidence. Lifecycle implementation, Status, Destroy, framework
installation, and connection summaries remain the next split delivery.
