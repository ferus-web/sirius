## Different *NIX API bindings
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

const SupportsLinuxPrctls* = defined(linux)

proc prctl*(
  op: int32,
  a2: uint64 = 0'u64,
  a3: uint64 = 0'u64,
  a4: uint64 = 0'u64,
  a5: uint64 = 0'u64,
): int32 {.importc, header: "<sys/prctl.h>", sideEffect.}

when SupportsLinuxPrctls:
  # We barely use any of these, but it's nice to have them here nonetheless.
  {.push header: "<linux/prctl.h>", importc.}
  let
    PR_CAP_AMBIENT*: int32
    PR_CAPBSET_READ*: int32
    PR_CAPBSET_DROP*: int32
    PR_SET_CHILD_SUBREAPER*: int32
    PR_GET_CHILD_SUBREAPER*: int32
    PR_SET_DUMPABLE*: int32
    PR_GET_DUMPABLE*: int32
    PR_SET_ENDIAN*: int32
    PR_GET_ENDIAN*: int32
    PR_SET_FP_MODE*: int32
    PR_GET_FP_MODE*: int32
    PR_SET_FPEMU*: int32
    PR_GET_FPEMU*: int32
    PR_SET_FPEXC*: int32
    PR_GET_FPEXC*: int32
    PR_SET_IO_FLUSHER*: int32
    PR_GET_IO_FLUSHER*: int32
    PR_SET_KEEPCAPS*: int32
    PR_GET_KEEPCAPS*: int32
    PR_MCE_KILL*: int32
    PR_MCE_KILL_GET*: int32
    PR_SET_MM*: int32
    PR_SET_VMA*: int32
    PR_SET_NAME*: int32
    PR_GET_NAME*: int32
    PR_SET_NO_NEW_PRIVS*: int32
    PR_GET_NO_NEW_PRIVS*: int32
    PR_PAC_RESET_KEYS*: int32
    PR_SET_PDEATHSIG*: int32
    PR_GET_PDEATHSIG*: int32
    PR_SET_PTRACER*: int32
    PR_SET_SECCOMP*: int32
    PR_GET_SECCOMP*: int32
    PR_SET_SECUREBITS*: int32
    PR_GET_SECUREBITS*: int32
    PR_GET_SPECULATION_CTRL*: int32
    PR_SET_SPECULATION_CTRL*: int32
    PR_SVE_SET_VL*: int32
    PR_SVE_GET_VL*: int32
    PR_SET_SYSCALL_USER_DISPATCH*: int32
    PR_SET_TAGGED_ADDR_CTRL*: int32
    PR_GET_TAGGED_ADDR_CTRL*: int32
    PR_TASK_PERF_EVENTS_DISABLE*: int32
    PR_TASK_PERF_EVENTS_ENABLE*: int32
    PR_SET_THP_DISABLE*: int32
    PR_GET_THP_DISABLE*: int32
    PR_GET_TID_ADDRESS*: int32
    PR_SET_TIMERSLACK*: int32
    PR_GET_TIMERSLACK*: int32
    PR_SET_TIMING*: int32
    PR_GET_TIMING*: int32
    PR_SET_TSC*: int32
    PR_GET_TSC*: int32
    PR_SET_UNALIGN*: int32
    PR_GET_UNALIGN*: int32
    PR_GET_AUXV*: int32
    PR_SET_MDWE*: int32
    PR_GET_MDWE*: int32
    PR_RISCV_SET_ICACHE_FLUSH_CTX*: int32
    PR_FUTEX_HASH*: int32
  {.pop.}
