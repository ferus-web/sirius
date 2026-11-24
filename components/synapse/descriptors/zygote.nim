## *Generated automatically by scanner. Do not edit!*
## **Source**: ipc/zygote.ipdl
import std/options
import components/synapse/[encoder, types]
import pkg/[results, shakar]

type ZygoteOp* {.pure, size: sizeof(uint16).} = enum
  Spawn = 0
