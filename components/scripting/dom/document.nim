## Implementation of `Document`'s DOM specification API
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strutils]
import
  components/js/runtime/prelude,
  components/dom/[dom, tags],
  components/scripting/dom/node,
  components/html/[parser, dom_utils],
  components/scripting/html/element/[htmlinputelement],
  components/scripting/html/htmlelement
import pkg/[chronicles, shakar]

logScope:
  topics = "dom/document"

type Document* = object of node.Node

proc bindJSElement(rt: Runtime, elem: dom.Element): JSValue =
  GC_ref(elem)
    # HACK: Basically, we do not want the Nim runtime to deallocate this node while we're still working with it, otherwise that causes absolutely scrumptious and delectable heisenbugs :3
    # NOTE: Maybe we should allocate the DOM with the current realm's GC, honestly. Leaving it up to Nim's runtime refcounting is already causing some problems.

  if elem of tags.HTMLInputElement:
    toJSHTMLInputElement(rt, tags.HTMLInputElement(elem))
  else:
    toHTMLElement(rt, elem)

proc implementationGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.implementation getter"
  undefined(rt)

proc URLGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.URL getter"
  undefined(rt)

proc documentURIGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.documentURI getter"
  undefined(rt)

proc compatModeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.compatMode getter"
  undefined(rt)

proc characterSetGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.characterSet getter"
  undefined(rt)

proc charsetGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.charset getter"
  undefined(rt)

proc inputEncodingGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.inputEncoding getter"
  undefined(rt)

proc contentTypeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.contentType getter"
  undefined(rt)

proc doctypeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.doctype getter"
  undefined(rt)

proc documentElementGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.documentElement getter"
  undefined(rt)

proc newDocument*(rt: Runtime): Document =
  Document()

proc getElementsByTagName(rt: Runtime, this: JSValue, qualifiedName: JSValue): JSValue =
  let tagName = rt.ToString(qualifiedName)

  let
    document = &this.getPrivateObject(dom.Document)
    target = document.getElementsByTagName(tagName)

  # TODO: Can we implement HTMLCollection some day?
  var elems = newSeq[JSValue](target.len)
  for i, elem in target:
    elems[i] = rt.toHTMLElement(elem)

  rt.wrap(ensureMove(elems))

proc getElementsByTagNameNS(
    rt: Runtime, this: JSValue, namespace: JSValue, localName: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::getElementsByTagNameNS()",
    namespace = rt.ToString(namespace), localName = rt.ToString(localName)
  undefined(rt)

proc getElementsByClassName(rt: Runtime, this: JSValue, classNames: JSValue): JSValue =
  warn "IMPLEMENTME: Document::getElementsByClassName()",
    classNames = rt.ToString(classNames)
  undefined(rt)

proc createElement(
    rt: Runtime, this: JSValue, localName: JSValue, options: JSValue
): JSValue =
  # TODO: options arg
  let
    document = &this.getPrivateObject(dom.Document)
    element = document.createElement(
      localName = document.factory.strToAtom(toLowerAscii(rt.ToString(localName))),
      namespace = Namespace.HTML,
    )

  bindJSElement(rt, element)

proc createElementNS(
    rt: Runtime,
    this: JSValue,
    namespace: JSValue,
    qualifiedName: JSValue,
    options: JSValue,
): JSValue =
  warn "IMPLEMENTME: Document::createElementNS()",
    namespace = rt.ToString(namespace),
    qualifiedName = rt.ToString(qualifiedName),
    options = rt.ToString(options)
  undefined(rt)

proc createDocumentFragment(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createDocumentFragment()"
  undefined(rt)

proc createTextNode(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createTextNode()", data = rt.ToString(data)
  undefined(rt)

proc createCDATASection(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createCDATASection()", data = rt.ToString(data)
  undefined(rt)

proc createComment(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createComment()", data = rt.ToString(data)
  undefined(rt)

proc createProcessingInstruction(
    rt: Runtime, this: JSValue, target: JSValue, data: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::createProcessingInstruction()",
    target = rt.ToString(target), data = rt.ToString(data)
  undefined(rt)

proc importNode(rt: Runtime, this: JSValue, node: JSValue, options: JSValue): JSValue =
  warn "IMPLEMENTME: Document::importNode()",
    node = rt.ToString(node), options = rt.ToString(options)
  undefined(rt)

proc adoptNode(rt: Runtime, this: JSValue, node: JSValue): JSValue =
  warn "IMPLEMENTME: Document::adoptNode()", node = rt.ToString(node)
  undefined(rt)

proc createAttribute(rt: Runtime, this: JSValue, localName: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createAttribute()", localName = rt.ToString(localName)
  undefined(rt)

proc createAttributeNS(
    rt: Runtime, this: JSValue, namespace: JSValue, qualifiedName: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::createAttributeNS()",
    namespace = rt.ToString(namespace), qualifiedName = rt.ToString(qualifiedName)
  undefined(rt)

proc createEvent(rt: Runtime, this: JSValue, iface: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createEvent()", iface = rt.ToString(iface)
  undefined(rt)

proc createRange(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document::createRange()"
  undefined(rt)

proc createNodeIterator(
    rt: Runtime, this: JSValue, root: JSValue, whatToShow: uint32, filter: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::createNodeIterator()",
    root = rt.ToString(root), whatToShow = whatToShow, filter = rt.ToString(filter)
  undefined(rt)

proc createTreeWalker(
    rt: Runtime, this: JSValue, root: JSValue, whatToShow: uint32, filter: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::createTreeWalker()",
    root = rt.ToString(root), whatToShow = whatToShow, filter = rt.ToString(filter)
  undefined(rt)

proc getElementById(rt: Runtime, this: JSValue, elementId: JSValue): JSValue =
  ## https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid

  # NOTE: Obviously, not spec compliant yet.
  let id = rt.ToString(elementId)

  let
    document = &this.getPrivateObject(dom.Document)
    target = document.getElementById(document.factory, id)

  if *target:
    bindJSElement(rt, &target)
  else:
    null(rt)

proc generateGlobal*(rt: Runtime, doc: dom.Document): JSValue =
  let documentObject = rt.createObjFromType(document.Document)
  documentObject.setHiddenField("internal", rt.wrap(hidden(doc)))

  rt.setGlobal("document", documentObject)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Document", document.Document)
  runtime.defineAccessor(
    Document,
    "implementation",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret implementationGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "URL",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret URLGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "documentURI",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret documentURIGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "compatMode",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret compatModeGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "characterSet",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret characterSetGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "charset",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret charsetGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "inputEncoding",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret inputEncodingGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "contentType",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret contentTypeGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "doctype",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret doctypeGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "documentElement",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret documentElementGetter(rt = runtime, this = this)
    ),
  )

  runtime.definePrototypeFn(
    Document,
    "getElementsByTagName",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      ret getElementsByTagName(rt = runtime, this = this, qualifiedName = qualifiedName)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "getElementsByTagNameNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let localName = &runtime.argument(2, required = true)
      ret getElementsByTagNameNS(
        rt = runtime, this = this, namespace = namespace, localName = localName
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "getElementsByClassName",
    proc(this: JSValue) =
      let classNames = &runtime.argument(1, required = true)
      ret getElementsByClassName(rt = runtime, this = this, classNames = classNames)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createElement",
    proc(this: JSValue) =
      let localName = &runtime.argument(1, required = true)
      let options = &runtime.argument(2, required = false)
      ret createElement(
        rt = runtime, this = this, localName = localName, options = options
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createElementNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let qualifiedName = &runtime.argument(2, required = true)
      let options = &runtime.argument(3, required = false)
      ret createElementNS(
        rt = runtime,
        this = this,
        namespace = namespace,
        qualifiedName = qualifiedName,
        options = options,
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createDocumentFragment",
    proc(this: JSValue) =
      ret createDocumentFragment(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createTextNode",
    proc(this: JSValue) =
      let data = &runtime.argument(1, required = true)
      ret createTextNode(rt = runtime, this = this, data = data)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createCDATASection",
    proc(this: JSValue) =
      let data = &runtime.argument(1, required = true)
      ret createCDATASection(rt = runtime, this = this, data = data)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createComment",
    proc(this: JSValue) =
      let data = &runtime.argument(1, required = true)
      ret createComment(rt = runtime, this = this, data = data)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createProcessingInstruction",
    proc(this: JSValue) =
      let target = &runtime.argument(1, required = true)
      let data = &runtime.argument(2, required = true)
      ret createProcessingInstruction(
        rt = runtime, this = this, target = target, data = data
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "importNode",
    proc(this: JSValue) =
      let node = &runtime.argument(1, required = true)
      let options = &runtime.argument(2, required = false)
      ret importNode(rt = runtime, this = this, node = node, options = options)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "adoptNode",
    proc(this: JSValue) =
      let node = &runtime.argument(1, required = true)
      ret adoptNode(rt = runtime, this = this, node = node)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createAttribute",
    proc(this: JSValue) =
      let localName = &runtime.argument(1, required = true)
      ret createAttribute(rt = runtime, this = this, localName = localName)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createAttributeNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let qualifiedName = &runtime.argument(2, required = true)
      ret createAttributeNS(
        rt = runtime, this = this, namespace = namespace, qualifiedName = qualifiedName
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createEvent",
    proc(this: JSValue) =
      let iface = &runtime.argument(1, required = true)
      ret createEvent(rt = runtime, this = this, iface = iface)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createRange",
    proc(this: JSValue) =
      ret createRange(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createNodeIterator",
    proc(this: JSValue) =
      let root = &runtime.argument(1, required = true)
      let whatToShow =
        uint32(&getFloat(runtime.ToNumeric(&runtime.argument(2, required = false))))
      let filter = &runtime.argument(3, required = false)
      ret createNodeIterator(
        rt = runtime, this = this, root = root, whatToShow = whatToShow, filter = filter
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "createTreeWalker",
    proc(this: JSValue) =
      let root = &runtime.argument(1, required = true)
      let whatToShow =
        uint32(&getFloat(runtime.ToNumeric(&runtime.argument(2, required = false))))
      let filter = &runtime.argument(3, required = false)
      ret createTreeWalker(
        rt = runtime, this = this, root = root, whatToShow = whatToShow, filter = filter
      )
    ,
  )

  runtime.definePrototypeFn(
    Document,
    "getElementById",
    proc(this: JSValue) =
      let elementId = &runtime.argument(1, required = true)
      ret getElementById(rt = runtime, this = this, elementId = elementId)
    ,
  )
