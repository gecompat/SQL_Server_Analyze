# Follow-up lifecycle

After external Docker and Podman evidence is available, the next bounded slice
adds `Start`, `Stop`, `Restart`, `Reset`, and `UpdateFramework`. These actions
must continue to use full saved object IDs, run-ID labels, explicit destructive
confirmation, and ignored local state.
