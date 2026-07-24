# Security boundary

The quick-test implementation operates only within its synthetic scope. It does
not change global Docker or Podman configuration, system resource limits,
firewall rules, or foreign containers, networks, and data. Secret values are
process-scoped or stored only in ignored local files with restricted access.
