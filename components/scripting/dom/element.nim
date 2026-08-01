## Very incomplete bindings for `Element`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables, strutils]
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[arguments, bridge, construction, types, wrapping],
  components/js/runtime/abstract/[coercible, to_number, to_string],
  components/dom/dom,
  components/html/[dom_utils, parser, serialization]
import pkg/shakar

type JSElement* = object of RootObj
  internal*: Hidden[dom.Element]
  textContent*, innerHTML*: FieldAccessor
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
    onwheel*: FieldAccessor

proc onclickSetter(rt: Runtime, this: JSValue, value: JSValue) =
  # i can't wait to do this for the 8234823842384 others :D
  const ClickEvent = "click"

  let element = &this.getPrivateObject(dom.Element)

  element.addEventListener(
    ClickEvent, EventListener(rt: rt, callback: value, setter: true)
  )

proc onkeydownSetter(rt: Runtime, this: JSValue, value: JSValue) =
  const KeydownEvent = "keydown"

  let element = &this.getPrivateObject(dom.Element)
  element.addEventListener(
    KeydownEvent, EventListener(rt: rt, callback: value, setter: true)
  )

proc onsubmitSetter(rt: Runtime, this: JSValue, value: JSValue) =
  const SubmitEvent = "submit"

  let element = &this.getPrivateObject(dom.Element)
  element.addEventListener(
    SubmitEvent, EventListener(rt: rt, callback: value, setter: true)
  )

proc getElementTextContentAccessor*(runtime: Runtime): FieldAccessor =
  FieldAccessor(
    getter: proc(this: JSValue) =
      ret textContent(&this.getPrivateObject(dom.Element))
    ,
    setter: proc(this: JSValue, value: JSValue) =
      let element = &this.getPrivateObject(dom.Element)
      element.childList.setLen(1)

      let textData = runtime.ToString(value)

      element.childList[0] = Text(data: textData, parentNode: element)
      element.document.edited = true,
  )

proc getInnerHTMLTextContentAccessor*(runtime: Runtime): FieldAccessor =
  FieldAccessor(
    getter: proc(this: JSValue) =
      ret serializeFragment(&this.getPrivateObject(dom.Node))
    ,
    setter: proc(this: JSValue, value: JSValue) {.gcsafe.} =
      let element = &this.getPrivateObject(dom.Element)
      {.cast(gcsafe).}:
        # FIXME: Why is this GC-unsafe?
        element.childList =
          parseHTMLFragment(runtime.ToString(value), element, MiniDOMBuilderCallbacks())
        element.document.edited = true
          # TODO: Provide proper callbacks here! Right now these'll just segfault and crash if any special stuff's found while parsing!!!!!
    ,
  )

proc getOnClickFieldAccessor*(runtime: Runtime): FieldAccessor =
  FieldAccessor(
    setter: proc(this: JSValue, value: JSValue) {.gcsafe.} =
      runtime.onclickSetter(this, value)
  )

proc getOnKeyDownFieldAccessor*(runtime: Runtime): FieldAccessor =
  FieldAccessor(
    setter: proc(this: JSValue, value: JSValue) {.gcsafe.} =
      runtime.onkeydownSetter(this, value)
  )

proc getOnSubmitFieldAccessor*(runtime: Runtime): FieldAccessor =
  FieldAccessor(
    setter: proc(this: JSValue, value: JSValue) {.gcsafe.} =
      runtime.onsubmitSetter(this, value)
  )

proc toJSElement*(runtime: Runtime, element: dom.Element): JSElement =
  JSElement(
    internal: hidden(element),
    textContent: getElementTextContentAccessor(runtime),
    innerHTML: getInnerHTMLTextContentAccessor(runtime),
    parentElement: (
      if element.parentNode != nil and element.parentNode of dom.Element:
        runtime.wrap(toJSElement(runtime, Element(element.parentNode)))
      else:
        null(runtime)
    ),
    localName: element.document.factory.atomToStr(element.localName),
    tagName: toUpperAscii(element.document.factory.atomToStr(element.localName)),
    onclick: getOnClickFieldAccessor(runtime),
    onkeydown: getOnKeyDownFieldAccessor(runtime),
    onsubmit: getOnSubmitFieldAccessor(runtime),
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
