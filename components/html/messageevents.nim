## Host implementation of `MessageEvent`
## https://html.spec.whatwg.org/multipage/comms.html#the-messageevent-interface
##
## Copyright C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/dom/dom

type MessageEvent* = ref object of dom.EventTarget
  # TODO: This should inherit from dom.Event when that works. Maybe the scripting version should just hold one too
  data*: string # TODO: Blob(s) and stuff
  origin*: string
  lastEventId*: string # TODO: ports, source

proc newMessageEvent*(data: string, origin: string, lastEventId: string): MessageEvent =
  MessageEvent(data: data, origin: origin, lastEventId: lastEventId)
