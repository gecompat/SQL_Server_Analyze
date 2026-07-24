# Docker/Podman quick-test acceptance boundary

The repository gate validates the quick-test vertical slice without requiring a
container host. It covers PowerShell parsing, deterministic defaults, password
complexity generation, port collision classification, resource-profile bounds,
path containment, structured Preflight blockers, Docker and Podman Compose
models, privacy, and exact cleanup contracts.

A successful repository gate is not runtime evidence. The gates
`LAB-GATE-QUICKTEST-DOCKER` and `LAB-GATE-QUICKTEST-PODMAN` remain
`NOT_EXECUTED` until the same public entrypoint has provisioned synthetic SQL
Server 2019, 2022, and 2025 instances on an approved native x86-64 Linux host.
