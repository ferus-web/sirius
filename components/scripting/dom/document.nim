## Implementation of routines for the `Document` type
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/strutils
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[arguments, bridge, construction, types],
  components/js/runtime/abstract/[coercible, to_number, to_string],
  components/dom/dom,
  components/html/dom_utils,
  components/scripting/dom/[element],
  components/net/[cookie, cookie_parser],
  components/aux/pretty
import pkg/shakar

type JSDocument* = object
  internal*: Hidden[dom.Document]
  cookie*: FieldAccessor

proc documentCookieSetter(this: JSValue, value: JSValue) =
  assert off

proc generateGlobal*(runtime: Runtime, doc: dom.Document): JSValue =
  runtime.setGlobal(
    "document",
    JSDocument(
      internal: hidden(doc),
      cookie: FieldAccessor(
        getter: proc(this: JSValue) =
          let document = &this.getPrivateObject(dom.Document)

          ret serialize(document.cookies)
        ,
        setter: proc(this: JSValue, value: JSValue) =
          let
            valueStr = runtime.ToString(value)
            document = &this.getPrivateObject(dom.Document)

          var cookies = newSeqOfCap[Cookie](valueStr.count(';'))

          for pair in valueStr.split(';'):
            let parsed = parseCookie(document.url, pair)
            if !parsed:
              return

            cookies &= &parsed

          document.cookies &= ensureMove(cookies),
      ),
    ),
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(prototype = JSDocument, name = "Document")

  runtime.definePrototypeFn(
    JSDocument,
    "getElementById",
    proc(this: JSValue) =
      # NOTE: Obviously, not spec compliant yet.
      let id = runtime.ToString(
        &runtime.argument(
          1,
          required = true,
          message = "document.getElementById() expects 1 argument, got {nargs}",
        )
      )

      let
        document = &this.getPrivateObject(dom.Document)
        target = document.getElementById(document.factory, id)

      if *target:
        ret toJSElement(runtime, &target)
      else:
        ret null(runtime)
    ,
  )

  runtime.definePrototypeFn(
    JSDocument,
    "getElementsByTagName",
    proc(this: JSValue) =
      let tagName = runtime.ToString(
        &runtime.argument(
          1,
          required = true,
          message = "document.getElementById() expects 1 argument, got {nargs}",
        )
      )

      let
        document = &this.getPrivateObject(dom.Document)
        target = document.getElementsByTagName(tagName)

      # TODO: Can we implement HTMLCollection some day?
      var elems = newSeq[JSElement](target.len)
      for i, elem in target:
        elems[i] = runtime.toJSElement(elem)

      ret ensureMove(elems)
    ,
  )
