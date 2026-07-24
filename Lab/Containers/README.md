# Container contracts

The existing `compose.yaml` and Docker override implement the digest-bound
single-container LAB-001 runtime used by Wellen 2 and 3.

The `quick-test.compose.*` files are a separate user-facing vertical slice:

- `quick-test.compose.yaml` is the shared Docker/Podman core;
- `quick-test.compose.docker.yaml` contains Docker-specific limits and labels;
- `quick-test.compose.podman.yaml` contains Podman-specific limits and labels.

The services are activated through the profiles `sql2019`, `sql2022`, and
`sql2025`. Inactive services have harmless interpolation defaults so a user may
select any subset without supplying unused paths or ports. Active values are
provided by `Lab/QuickTest/QuickTestLab.psm1` after read-only Preflight.

The SQL administrative secret is never written into these files. Compose
receives it only from the current process environment and passes it to the
selected containers. All containers and the shared network carry the synthetic
scope and run-ID labels used for Status and Destroy verification.
