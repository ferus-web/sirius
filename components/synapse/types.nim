## Core wire types for IPC
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options

const
  OpPosition* = 0
  ArgcPosition* = 2

type
  SharedMemory* = distinct int32 ## A file descriptor pointing to a shm

  Encoder* = ref object
    buffer: string
    argc: uint8

  EncodedBuffer* = distinct string

  Decoder* = ref object
    buffer: string

  ProcessKind* {.pure, size: sizeof(uint8).} = enum
    Zygote
    Renderer
    Network

  ProcessObj = object
    fd*: int32 ## the end of the socketpair that we (the master) need to hold
    kind*: ProcessKind

  Process* = ref ProcessObj

  ClientObj = object
    fd*: int32 ## the end of the socketpair that we (the child) need to hold

  Client* = ref ClientObj

  TabObj = object
    processes*: seq[Process]

  Tab* = ref TabObj

  MasterObj = object
    tabs*: seq[Tab]
    zygote*: Process

    encoder*: Encoder
    decoder*: Decoder

  Master* = ref MasterObj

  Message*[O: enum] = object
    op*: O
    argc*: uint8
    buffer*: string
