## Very incomplete bindings for `Element`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/strutils
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[arguments, bridge, construction, types, wrapping],
  components/js/runtime/abstract/[coercible, to_number, to_string],
  components/dom/dom,
  components/html/dom_utils
import pkg/shakar

type JSElement* = object
  internal*: Hidden[dom.Element]
  textContent*: FieldAccessor
  parentElement*: JSValue

  localName*, tagName*: string

  onabort*, onauxclick*, onbeforeinput*, onbeforematch*, onbeforetoggle*, onblur*,
    oncancel*, oncanplay*, oncanplaythrough*, onchange*, onclick*, onclose*, oncommand*,
    oncontextlost*, oncontextmenu*, oncontextrestored*, oncopy*, oncuechange*, oncut*,
    ondblclick*, ondrag*, ondragend*, ondragenter*, ondragleave*, ondragover*,
    ondragstart*, ondrop*, ondurationchange*, onemptied*, onended*, onfocus*,
    onformdata*, oninput*, oninvalid*, onkeydown*, onkeypress*, onkeyup*, onload*,
    onloadeddata*, onloadedmetadata*, onloadstart*, onmousedown*, onmouseenter*,
    onmouseleave*, onmousemove*, onmouseout*, onmouseover*, onmouseup*, onpaste*,
    onpause*, onplay*, onplaying*, onprogress*, onratechange*, onreset*, onresize*,
    onscroll*, onscrollend*, onsecuritypolicyviolation*, onseeked*, onseeking*,
    onselect*, onslotchange*, onstalled*, onsubmit*, onsuspend*, ontimeupdate*,
    ontoggle*, onvolumechange*, onwaiting*, onwebkitanimationend*,
    onwebkitanimationiteration*, onwebkitanimationstart*, onwebkittransitionend*,
    onwheel*: JSValue

proc toJSElement*(runtime: Runtime, element: dom.Element): JSElement =
  JSElement(
    internal: hidden(element),
    textContent: FieldAccessor(
      getter: proc(this: JSValue) =
        ret textContent(&this.getPrivateObject(dom.Element))
      ,
      setter: proc(this: JSValue, value: JSValue) =
        let element = &this.getPrivateObject(dom.Element)
        element.childList.setLen(1)

        let textData = runtime.ToString(value)

        if textData.len > 0:
          element.childList[0] = Text(data: textData, parentNode: element)

        element.document.edited = true,
    ),
    parentElement: (
      if element.parentNode != nil and element.parentNode of dom.Element:
        runtime.wrap(toJSElement(runtime, Element(element.parentNode)))
      else:
        null(runtime)
    ),
    localName: element.document.factory.atomToStr(element.localName),
    tagName: toUpperAscii(element.document.factory.atomToStr(element.localName)),
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(prototype = JSElement, name = "Element")
  runtime.definePrototypeFn(
    JSElement,
    "toString",
    proc(this: JSValue) =
      ret "[object Element]"
    ,
  )
