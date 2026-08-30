## Initialization routines for sandboxing on Linux
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/posix
import components/impure/nix
import pkg/[chronicles, results, shakar]

logScope:
  topics = "sandbox/linux/init"

proc posixError(): string {.inline.} =
  $posix.strerror(posix.errno)

proc applyPrctlCalls(): Result[void, string] =
  if nix.prctl(nix.PR_SET_NO_NEW_PRIVS, 1'u64) != 0:
    # We will _NEVER_ escalate our privileges, no matter what, under normal conditions
    return err(posixError())

  when defined(release):
    if nix.prctl(nix.PR_SET_DUMPABLE, 0'u64) != 0:
      # We don't want others poking and prodding at our memory.
      return err(posixError())

  if nix.prctl(nix.PR_SET_MDWE, 1'u64) != 0:
    # We don't want to map or mprotect() into existence, pages that are simultaneously writable AND executable
    warn "Failed to enable memory-deny-write-execute, W^X enforcement is disabled! D:",
      err = posixError()

  ok()

proc applyResourceLimits(): Result[void, string] =
  var lim: posix.RLimit

  when defined(release):
    # We don't want coredumps to be dumped to disk.
    lim.rlim_cur = 0
    lim.rlim_max = 0

    if posix.setrlimit(nix.RLIMIT_CORE, lim) != 0:
      return err(posixError())

  # We don't really use message queues, so we might as well forbid making them.
  lim.rlim_cur = 0
  lim.rlim_max = 0
  if posix.setrlimit(nix.RLIMIT_MSGQUEUE, lim) != 0:
    return err(posixError())

  ok()

proc initSandboxLinuxImpl*(): Result[void, string] =
  ## Set up the process' state to make it ready for sandboxing.
  ##
  ## **Note**: This does not set up sandboxing on its own. It simply makes a lot of
  ## calls to disable certain things and harden the process.

  if (let prctlsResult = applyPrctlCalls(); !prctlsResult):
    return prctlsResult

  if (let limitsResult = applyResourceLimits(); !limitsResult):
    return limitsResult

  ok()
