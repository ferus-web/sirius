## Implementation of `GlobalEventHandlers`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude

type
  EventHandler* = JSValue
  OnErrorEventHandler* = JSValue

  GlobalEventHandlers* = object
    onabort*, onauxclick*, onbeforeinput*, onbeforematch*, onbeforetoggle*, onblur*,
      oncancel*, oncanplay*, oncanplaythrough*, onchange*, onclick*, onclose*,
      oncommand*, oncontextlost*, oncontextmenu*, oncontextrestored*, oncopy*,
      oncuechange*, oncut*, ondblclick*, ondrag*, ondragend*, ondragenter*,
      ondragleave*, ondragover*, ondragstart*, ondrop*, ondurationchange*, onemptied*,
      onended*, onfocus*, onformdata*, oninput*, oninvalid*, onkeydown*, onkeypress*,
      onkeyup*, onload*, onloadeddata*, onloadedmetadata*, onloadstart*, onmousedown*,
      onmouseenter*, onmouseleave*, onmousemove*, onmouseout*, onmouseover*, onmouseup*,
      onpaste*, onpause*, onplay*, onplaying*, onprogress*, onratechange*, onreset*,
      onresize*, onscroll*, onscrollend*, onsecuritypolicyviolation*, onseeked*,
      onseeking*, onselect*, onslotchange*, onstalled*, onsubmit*, onsuspend*,
      ontimeupdate*, ontoggle*, onvolumechange*, onwaiting*, onwebkitanimationend*,
      onwebkitanimationiteration*, onwebkitanimationstart*, onwebkittransitionend*,
      onwheel*: EventHandler

    onerror*: OnErrorEventHandler
