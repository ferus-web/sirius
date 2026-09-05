## `Node` interface implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import
  components/js/runtime/prelude,
  components/scripting/dom/event_target,
  components/dom/dom
import pkg/[chronicles, shakar]

logScope:
  topics = "dom/node"

type Node* = object of EventTarget
  #[ nodeType*: FieldAccessor
  nodeName*: FieldAccessor
  baseURI*: FieldAccessor
  isConnected*: FieldAccessor
  ownerDocument*: FieldAccessor
  parentNode*: FieldAccessor
  parentElement*: FieldAccessor
  childNodes*: FieldAccessor
  firstChild*: FieldAccessor
  lastChild*: FieldAccessor
  previousSibling*: FieldAccessor
  nextSibling*: FieldAccessor
  nodeValue*: FieldAccessor
  textContent*: FieldAccessor ]#
  internal*: Hidden[dom.Node]

const
  ElementNode*: uint16 = 1
  AttributeNode*: uint16 = 2
  TextNode*: uint16 = 3
  CdataSectionNode*: uint16 = 4
  EntityReferenceNode*: uint16 = 5
  EntityNode*: uint16 = 6
  ProcessingInstructionNode*: uint16 = 7
  CommentNode*: uint16 = 8
  DocumentNode*: uint16 = 9
  DocumentTypeNode*: uint16 = 10
  DocumentFragmentNode*: uint16 = 11
  NotationNode*: uint16 = 12
  DocumentPositionDisconnected*: uint16 = 1
  DocumentPositionPreceding*: uint16 = 2
  DocumentPositionFollowing*: uint16 = 4
  DocumentPositionContains*: uint16 = 8
  DocumentPositionContainedBy*: uint16 = 16
  DocumentPositionImplementationSpecific*: uint16 = 32

proc nodeTypeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.nodeType getter"
  undefined(rt)

proc nodeNameGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.nodeName getter"
  undefined(rt)

proc baseURIGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.baseURI getter"
  undefined(rt)

proc isConnectedGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.isConnected getter"
  undefined(rt)

proc ownerDocumentGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.ownerDocument getter"
  undefined(rt)

proc parentNodeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.parentNode getter"
  undefined(rt)

proc parentElementGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.parentElement getter"
  undefined(rt)

proc childNodesGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.childNodes getter"
  undefined(rt)

proc firstChildGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.firstChild getter"
  undefined(rt)

proc lastChildGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.lastChild getter"
  undefined(rt)

proc previousSiblingGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.previousSibling getter"
  undefined(rt)

proc nextSiblingGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.nextSibling getter"
  undefined(rt)

proc nodeValueGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.nodeValue getter"
  undefined(rt)

proc nodeValueSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Node.nodeValue setter"

proc textContentGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node.textContent getter"
  undefined(rt)

proc textContentSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Node.textContent setter"

proc getRootNode(rt: Runtime, this: JSValue, options: JSValue): JSValue =
  warn "IMPLEMENTME: Node::getRootNode()", options = rt.ToString(options)
  undefined(rt)

proc hasChildNodes(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node::hasChildNodes()"
  undefined(rt)

proc normalize(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Node::normalize()"
  undefined(rt)

proc cloneNode(rt: Runtime, this: JSValue, subtree: bool): JSValue =
  warn "IMPLEMENTME: Node::cloneNode()", subtree = subtree
  undefined(rt)

proc isEqualNode(rt: Runtime, this: JSValue, otherNode: JSValue): JSValue =
  warn "IMPLEMENTME: Node::isEqualNode()", otherNode = rt.ToString(otherNode)
  undefined(rt)

proc isSameNode(rt: Runtime, this: JSValue, otherNode: JSValue): JSValue =
  warn "IMPLEMENTME: Node::isSameNode()", otherNode = rt.ToString(otherNode)
  undefined(rt)

proc compareDocumentPosition(rt: Runtime, this: JSValue, other: JSValue): JSValue =
  warn "IMPLEMENTME: Node::compareDocumentPosition()", other = rt.ToString(other)
  undefined(rt)

proc contains(rt: Runtime, this: JSValue, other: JSValue): JSValue =
  warn "IMPLEMENTME: Node::contains()", other = rt.ToString(other)
  undefined(rt)

proc lookupPrefix(rt: Runtime, this: JSValue, namespace: JSValue): JSValue =
  warn "IMPLEMENTME: Node::lookupPrefix()", namespace = rt.ToString(namespace)
  undefined(rt)

proc lookupNamespaceURI(rt: Runtime, this: JSValue, prefix: JSValue): JSValue =
  warn "IMPLEMENTME: Node::lookupNamespaceURI()", prefix = rt.ToString(prefix)
  undefined(rt)

proc isDefaultNamespace(rt: Runtime, this: JSValue, namespace: JSValue): JSValue =
  warn "IMPLEMENTME: Node::isDefaultNamespace()", namespace = rt.ToString(namespace)
  undefined(rt)

proc insertBefore(rt: Runtime, this: JSValue, node: JSValue, child: JSValue): JSValue =
  warn "IMPLEMENTME: Node::insertBefore()",
    node = rt.ToString(node), child = rt.ToString(child)
  undefined(rt)

proc appendChild(rt: Runtime, this: JSValue, node: JSValue): JSValue =
  warn "IMPLEMENTME: Node::appendChild()", node = rt.ToString(node)
  undefined(rt)

proc replaceChild(rt: Runtime, this: JSValue, node: JSValue, child: JSValue): JSValue =
  warn "IMPLEMENTME: Node::replaceChild()",
    node = rt.ToString(node), child = rt.ToString(child)
  undefined(rt)

proc removeChild(rt: Runtime, this: JSValue, child: JSValue): JSValue =
  warn "IMPLEMENTME: Node::removeChild()", child = rt.ToString(child)
  undefined(rt)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Node", Node)
  runtime.setProperty(Node, "ELEMENT_NODE", ElementNode)
  runtime.setProperty(Node, "ATTRIBUTE_NODE", AttributeNode)
  runtime.setProperty(Node, "TEXT_NODE", TextNode)
  runtime.setProperty(Node, "CDATA_SECTION_NODE", CdataSectionNode)
  runtime.setProperty(Node, "ENTITY_REFERENCE_NODE", EntityReferenceNode)
  runtime.setProperty(Node, "ENTITY_NODE", EntityNode)
  runtime.setProperty(Node, "PROCESSING_INSTRUCTION_NODE", ProcessingInstructionNode)
  runtime.setProperty(Node, "COMMENT_NODE", CommentNode)
  runtime.setProperty(Node, "DOCUMENT_NODE", DocumentNode)
  runtime.setProperty(Node, "DOCUMENT_TYPE_NODE", DocumentTypeNode)
  runtime.setProperty(Node, "DOCUMENT_FRAGMENT_NODE", DocumentFragmentNode)
  runtime.setProperty(Node, "NOTATION_NODE", NotationNode)
  runtime.setProperty(
    Node, "DOCUMENT_POSITION_DISCONNECTED", DocumentPositionDisconnected
  )
  runtime.setProperty(Node, "DOCUMENT_POSITION_PRECEDING", DocumentPositionPreceding)
  runtime.setProperty(Node, "DOCUMENT_POSITION_FOLLOWING", DocumentPositionFollowing)
  runtime.setProperty(Node, "DOCUMENT_POSITION_CONTAINS", DocumentPositionContains)
  runtime.setProperty(
    Node, "DOCUMENT_POSITION_CONTAINED_BY", DocumentPositionContainedBy
  )
  runtime.setProperty(
    Node, "DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC",
    DocumentPositionImplementationSpecific,
  )

  runtime.definePrototypeFn(
    Node,
    "getRootNode",
    proc(this: JSValue) =
      let options = &runtime.argument(1, required = false)
      ret getRootNode(rt = runtime, this = this, options = options)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "hasChildNodes",
    proc(this: JSValue) =
      ret hasChildNodes(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "normalize",
    proc(this: JSValue) =
      ret normalize(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "cloneNode",
    proc(this: JSValue) =
      let subtree = &getBool(&runtime.argument(1, required = false))
      ret cloneNode(rt = runtime, this = this, subtree = subtree)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "isEqualNode",
    proc(this: JSValue) =
      let otherNode = &runtime.argument(1, required = true)
      ret isEqualNode(rt = runtime, this = this, otherNode = otherNode)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "isSameNode",
    proc(this: JSValue) =
      let otherNode = &runtime.argument(1, required = true)
      ret isSameNode(rt = runtime, this = this, otherNode = otherNode)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "compareDocumentPosition",
    proc(this: JSValue) =
      let other = &runtime.argument(1, required = true)
      ret compareDocumentPosition(rt = runtime, this = this, other = other)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "contains",
    proc(this: JSValue) =
      let other = &runtime.argument(1, required = true)
      ret contains(rt = runtime, this = this, other = other)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "lookupPrefix",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      ret lookupPrefix(rt = runtime, this = this, namespace = namespace)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "lookupNamespaceURI",
    proc(this: JSValue) =
      let prefix = &runtime.argument(1, required = true)
      ret lookupNamespaceURI(rt = runtime, this = this, prefix = prefix)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "isDefaultNamespace",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      ret isDefaultNamespace(rt = runtime, this = this, namespace = namespace)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "insertBefore",
    proc(this: JSValue) =
      let node = &runtime.argument(1, required = true)
      let child = &runtime.argument(2, required = true)
      ret insertBefore(rt = runtime, this = this, node = node, child = child)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "appendChild",
    proc(this: JSValue) =
      let node = &runtime.argument(1, required = true)
      ret appendChild(rt = runtime, this = this, node = node)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "replaceChild",
    proc(this: JSValue) =
      let node = &runtime.argument(1, required = true)
      let child = &runtime.argument(2, required = true)
      ret replaceChild(rt = runtime, this = this, node = node, child = child)
    ,
  )

  runtime.definePrototypeFn(
    Node,
    "removeChild",
    proc(this: JSValue) =
      let child = &runtime.argument(1, required = true)
      ret removeChild(rt = runtime, this = this, child = child)
    ,
  )
