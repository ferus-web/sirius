# Zygote IPC calls
**Author**: Trayambak Rai (`xtrayambak@disroot.org`)

## Master => Zygote
### spawn
**Argument 1**: ProcessKind
**Argument 2**: FD

Spawns a process with that very same `ProcessKind`. The shared file descriptor will be used by this newly spawned process to talk to the master, and as such, it must be valid.
