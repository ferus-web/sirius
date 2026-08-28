## Core wire types for IPC
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import pkg/url

const
  OpPosition* = 0
  ArgcPosition* = 2

type
  FileDescriptor* = distinct int32
  SharedMemory* = distinct int32 ## A file descriptor pointing to a shm

  Encoder* = ref object
    buffer*: string
    argc: uint8

    fds*: seq[int32]

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

  ZygoteRoutine* = proc(fd: int32)

  ClientObj = object
    fd*: int32 ## the end of the socketpair that we (the child) need to hold

    encoder*: Encoder
    decoder*: Decoder

    running*: bool ## Is the master process still alive?

  Client* = ref ClientObj

  TabObj = object
    url*: URL
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

    fds*: seq[int32]
