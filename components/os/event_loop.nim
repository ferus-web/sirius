## Implementation of a basic event loop abstraction with certain primitives
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, sets, strformat]
import pkg/results

const
  UsingEpoll* = defined(linux)
  EventPreallocCount* = 16

when UsingEpoll:
  import std/posix
  import components/impure/nix

import pkg/[chronicles]

logScope:
  topics = "os/event_loop"

type
  EventMode* {.pure, size: sizeof(uint8).} = enum
    Input = 0
    Output = 1
    Hangup = 2

  TriggerKind* {.pure, size: sizeof(uint8).} = enum
    ## All the different kind of event loop triggers, for now.
    IPC
    WebSocket

  Trigger* = ref object
    kind*: TriggerKind

    when UsingEpoll:
      fd*: int32

  Event* = object
    trigger*: Trigger
    modes*: set[EventMode]

  EventLoopObj = object
    when UsingEpoll:
      fd: int32 ## the epoll file descriptor
      epollBuffer: seq[nix.EpollEvent]

    triggers: HashSet[Trigger]
    buffer: seq[Event]
      ## list of all triggers that are ready for one type of event or the other

  EventLoop* = ref EventLoopObj

proc `=destroy`*(loop: EventLoopObj) =
  info "Destroying EventLoop instance"

  when UsingEpoll:
    debug "Closing epoll instance", epollFd = loop.fd
    discard posix.close(loop.fd)

func hash*(trigger: Trigger): Hash =
  hash(trigger.fd)

func ipc*(fd: int32): Trigger =
  Trigger(kind: TriggerKind.IPC, fd: fd)

func websocket*(fd: int32): Trigger =
  Trigger(kind: TriggerKind.WebSocket, fd: fd)

proc unregister*(loop: EventLoop, trigger: Trigger): Result[void, string] =
  when UsingEpoll:
    if not loop.triggers.contains(trigger):
      return err(
        &"Trigger <{trigger.fd}> was never registered prior on this event loop, or it has already been unregistered."
      )

    debug "Unregistering trigger from event loop", kind = trigger.kind, fd = trigger.fd

    var event: nix.EpollEvent
    if nix.epoll_ctl(loop.fd, nix.EPOLL_CTL_DEL, trigger.fd, event.addr) != 0:
      return err(
        &"Failed to detach trigger <{trigger.fd}> from loop <{loop.fd}>: {posix.strerror(posix.errno)} ({posix.errno})"
      )

    GC_unref(trigger)
      # don't leak the trigger since we artificially inc'd the refcount once below in EventLoop::register()

    loop.triggers.excl(trigger)
    loop.buffer = newSeqOfCap[Event](loop.triggers.len)
      # reallocate the buffer with the new number of active triggers

    ok()
  else:
    {.error: "Implement EventLoop::unregister() for your platform!".}

proc register*(
    loop: EventLoop, trigger: Trigger, modes: set[EventMode]
): Result[void, string] =
  when UsingEpoll:
    if trigger.fd < 0'i32:
      return err(&"Invalid file descriptor: {trigger.fd}")

    if loop.triggers.contains(trigger):
      return err(
        &"Cannot register trigger on same descriptor twice! Unregister the preceding trigger first."
      )

    debug "Registering trigger to event loop", kind = trigger.kind, fd = trigger.fd

    var eventsSet: uint32
    if EventMode.Input in modes:
      eventsSet = eventsSet or nix.EPOLLIN

    if EventMode.Output in modes:
      eventsSet = eventsSet or nix.EPOLLOUT

    if EventMode.Hangup in modes:
      eventsSet = eventsSet or nix.EPOLLHUP

    # OPTIMIZATION: we'll stuff the trigger into the epoll listener data so we don't need to do silly lookups every time an event is polled for it
    # NOTE: ensure that this can _NEVER_ blow up or cause problems.
    GC_ref(trigger)
    var event = nix.EpollEvent(
      events: eventsSet, data: nix.EpollData(fd: trigger.fd, u64: cast[uint64](trigger))
    )

    if nix.epoll_ctl(loop.fd, nix.EPOLL_CTL_ADD, trigger.fd, event.addr) != 0:
      return err(
        &"Failed to attach trigger <{trigger.fd}> to loop <{loop.fd}>: {posix.strerror(posix.errno)} ({posix.errno})"
      )

    loop.triggers.incl(trigger)

    ok()
  else:
    {.error: "Implement EventLoop::register() for your platform!".}

proc wait*(loop: EventLoop): Result[seq[Event], string] {.raises: [KeyError].} =
  loop.buffer.setLen(loop.triggers.len)
  loop.epollBuffer.setLen(loop.triggers.len)

  when UsingEpoll:
    let eventCount = nix.epoll_wait(
      loop.fd,
      loop.epollBuffer[0].addr,
      maxevents = cast[int32](loop.epollBuffer.len),
      timeout = 1'i32,
    ) # TODO: do something about the timeout

    if eventCount < 0'i32:
      return err(
        &"Failed to wait on loop <{loop.fd}>: {posix.strerror(posix.errno)} ({posix.errno})"
      )

    var events = newSeq[Event](eventCount)

    for i in 0 ..< eventCount:
      let event = loop.epollBuffer[i]

      var modes: set[EventMode]
      if (event.events and nix.EPOLLIN) != 0'u32:
        modes.incl(EventMode.Input)

      if (event.events and nix.EPOLLOUT) != 0'u32:
        modes.incl(EventMode.Output)

      if (event.events and nix.EPOLLHUP) != 0'u32:
        modes.incl(EventMode.Hangup)

      events[i] = Event(trigger: cast[Trigger](event.data.u64), modes: modes)

    ok(ensureMove(events))
  else:
    {.error: "Implement EventLoop::wait() for your platform!".}

proc initEventLoop*(): Result[EventLoop, string] =
  when UsingEpoll:
    let efd = nix.epoll_create1(0)
    if efd < 0'i32:
      return
        err(&"Cannot create event loop: {posix.strerror(posix.errno)} ({posix.errno})")

    ok(
      EventLoop(
        fd: efd,
        triggers: initHashSet[Trigger](EventPreallocCount),
        buffer: newSeqOfCap[Event](EventPreallocCount),
        epollBuffer: newSeqOfCap[nix.EpollEvent](EventPreallocCount),
      )
    )
  else:
    {.error: "Implement initEventLoop() for your platform!".}
