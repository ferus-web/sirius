import components/js/runtime/prelude, components/scripting/dom/node, components/dom/dom
import pkg/[chronicles, shakar]

logScope:
  topics = "dom/element"

type Element* = object of node.Node

proc namespaceURIGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.namespaceURI getter"
  undefined(rt)

proc prefixGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.prefix getter"
  undefined(rt)

proc localNameGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.localName getter"
  undefined(rt)

proc tagNameGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.tagName getter"
  undefined(rt)

proc idGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.id getter"
  undefined(rt)

proc idSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Element.id setter"

proc classNameGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.className getter"
  undefined(rt)

proc classNameSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Element.className setter"

proc classListGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.classList getter"
  undefined(rt)

proc slotGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.slot getter"
  undefined(rt)

proc slotSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Element.slot setter"

proc attributesGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.attributes getter"
  undefined(rt)

proc shadowRootGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.shadowRoot getter"
  undefined(rt)

proc customElementRegistryGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element.customElementRegistry getter"
  undefined(rt)

proc hasAttributes(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element::hasAttributes()"
  undefined(rt)

proc getAttributeNames(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Element::getAttributeNames()"
  undefined(rt)

proc getAttribute(rt: Runtime, this: JSValue, qualifiedName: JSValue): JSValue =
  warn "IMPLEMENTME: Element::getAttribute()",
    qualifiedName = rt.ToString(qualifiedName)
  undefined(rt)

proc getAttributeNS(
    rt: Runtime, this: JSValue, namespace: JSValue, localName: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::getAttributeNS()",
    namespace = rt.ToString(namespace), localName = rt.ToString(localName)
  undefined(rt)

proc setAttribute(
    rt: Runtime, this: JSValue, qualifiedName: JSValue, value: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::setAttribute()",
    qualifiedName = rt.ToString(qualifiedName), value = rt.ToString(value)
  undefined(rt)

proc setAttributeNS(
    rt: Runtime,
    this: JSValue,
    namespace: JSValue,
    qualifiedName: JSValue,
    value: JSValue,
): JSValue =
  warn "IMPLEMENTME: Element::setAttributeNS()",
    namespace = rt.ToString(namespace),
    qualifiedName = rt.ToString(qualifiedName),
    value = rt.ToString(value)
  undefined(rt)

proc removeAttribute(rt: Runtime, this: JSValue, qualifiedName: JSValue): JSValue =
  warn "IMPLEMENTME: Element::removeAttribute()",
    qualifiedName = rt.ToString(qualifiedName)
  undefined(rt)

proc removeAttributeNS(
    rt: Runtime, this: JSValue, namespace: JSValue, localName: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::removeAttributeNS()",
    namespace = rt.ToString(namespace), localName = rt.ToString(localName)
  undefined(rt)

proc toggleAttribute(
    rt: Runtime, this: JSValue, qualifiedName: JSValue, force: bool
): JSValue =
  warn "IMPLEMENTME: Element::toggleAttribute()",
    qualifiedName = rt.ToString(qualifiedName), force = force
  undefined(rt)

proc hasAttribute(rt: Runtime, this: JSValue, qualifiedName: JSValue): JSValue =
  warn "IMPLEMENTME: Element::hasAttribute()",
    qualifiedName = rt.ToString(qualifiedName)
  undefined(rt)

proc hasAttributeNS(
    rt: Runtime, this: JSValue, namespace: JSValue, localName: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::hasAttributeNS()",
    namespace = rt.ToString(namespace), localName = rt.ToString(localName)
  undefined(rt)

proc getAttributeNode(rt: Runtime, this: JSValue, qualifiedName: JSValue): JSValue =
  warn "IMPLEMENTME: Element::getAttributeNode()",
    qualifiedName = rt.ToString(qualifiedName)
  undefined(rt)

proc getAttributeNodeNS(
    rt: Runtime, this: JSValue, namespace: JSValue, localName: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::getAttributeNodeNS()",
    namespace = rt.ToString(namespace), localName = rt.ToString(localName)
  undefined(rt)

proc setAttributeNode(rt: Runtime, this: JSValue, attr: JSValue): JSValue =
  warn "IMPLEMENTME: Element::setAttributeNode()", attr = rt.ToString(attr)
  undefined(rt)

proc setAttributeNodeNS(rt: Runtime, this: JSValue, attr: JSValue): JSValue =
  warn "IMPLEMENTME: Element::setAttributeNodeNS()", attr = rt.ToString(attr)
  undefined(rt)

proc removeAttributeNode(rt: Runtime, this: JSValue, attr: JSValue): JSValue =
  warn "IMPLEMENTME: Element::removeAttributeNode()", attr = rt.ToString(attr)
  undefined(rt)

proc attachShadow(rt: Runtime, this: JSValue, init: JSValue): JSValue =
  warn "IMPLEMENTME: Element::attachShadow()", init = rt.ToString(init)
  undefined(rt)

proc closest(rt: Runtime, this: JSValue, selectors: JSValue): JSValue =
  warn "IMPLEMENTME: Element::closest()", selectors = rt.ToString(selectors)
  undefined(rt)

proc matches(rt: Runtime, this: JSValue, selectors: JSValue): JSValue =
  warn "IMPLEMENTME: Element::matches()", selectors = rt.ToString(selectors)
  undefined(rt)

proc webkitMatchesSelector(rt: Runtime, this: JSValue, selectors: JSValue): JSValue =
  warn "IMPLEMENTME: Element::webkitMatchesSelector()",
    selectors = rt.ToString(selectors)
  undefined(rt)

proc getElementsByTagName(rt: Runtime, this: JSValue, qualifiedName: JSValue): JSValue =
  warn "IMPLEMENTME: Element::getElementsByTagName()",
    qualifiedName = rt.ToString(qualifiedName)
  undefined(rt)

proc getElementsByTagNameNS(
    rt: Runtime, this: JSValue, namespace: JSValue, localName: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::getElementsByTagNameNS()",
    namespace = rt.ToString(namespace), localName = rt.ToString(localName)
  undefined(rt)

proc getElementsByClassName(rt: Runtime, this: JSValue, classNames: JSValue): JSValue =
  warn "IMPLEMENTME: Element::getElementsByClassName()",
    classNames = rt.ToString(classNames)
  undefined(rt)

proc insertAdjacentElement(
    rt: Runtime, this: JSValue, where: JSValue, element: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::insertAdjacentElement()",
    where = rt.ToString(where), element = rt.ToString(element)
  undefined(rt)

proc insertAdjacentText(
    rt: Runtime, this: JSValue, where: JSValue, data: JSValue
): JSValue =
  warn "IMPLEMENTME: Element::insertAdjacentText()",
    where = rt.ToString(where), data = rt.ToString(data)
  undefined(rt)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Element", Element)
  runtime.defineAccessor(
    Element,
    "namespaceURI",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret namespaceURIGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "prefix",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret prefixGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "localName",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret localNameGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "tagName",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret tagNameGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "id",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret idGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        idSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Element,
    "className",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret classNameGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        classNameSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Element,
    "classList",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret classListGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "slot",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret slotGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        slotSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Element,
    "attributes",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret attributesGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "shadowRoot",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret shadowRootGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Element,
    "customElementRegistry",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret customElementRegistryGetter(rt = runtime, this = this)
    ),
  )

  runtime.definePrototypeFn(
    Element,
    "hasAttributes",
    proc(this: JSValue) =
      ret hasAttributes(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "getAttributeNames",
    proc(this: JSValue) =
      ret getAttributeNames(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "getAttribute",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      ret getAttribute(rt = runtime, this = this, qualifiedName = qualifiedName)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "getAttributeNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let localName = &runtime.argument(2, required = true)
      ret getAttributeNS(
        rt = runtime, this = this, namespace = namespace, localName = localName
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "setAttribute",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      let value = &runtime.argument(2, required = true)
      ret setAttribute(
        rt = runtime, this = this, qualifiedName = qualifiedName, value = value
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "setAttributeNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let qualifiedName = &runtime.argument(2, required = true)
      let value = &runtime.argument(3, required = true)
      ret setAttributeNS(
        rt = runtime,
        this = this,
        namespace = namespace,
        qualifiedName = qualifiedName,
        value = value,
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "removeAttribute",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      ret removeAttribute(rt = runtime, this = this, qualifiedName = qualifiedName)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "removeAttributeNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let localName = &runtime.argument(2, required = true)
      ret removeAttributeNS(
        rt = runtime, this = this, namespace = namespace, localName = localName
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "toggleAttribute",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      let force = &getBool(&runtime.argument(2, required = false))
      ret toggleAttribute(
        rt = runtime, this = this, qualifiedName = qualifiedName, force = force
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "hasAttribute",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      ret hasAttribute(rt = runtime, this = this, qualifiedName = qualifiedName)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "hasAttributeNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let localName = &runtime.argument(2, required = true)
      ret hasAttributeNS(
        rt = runtime, this = this, namespace = namespace, localName = localName
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "getAttributeNode",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      ret getAttributeNode(rt = runtime, this = this, qualifiedName = qualifiedName)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "getAttributeNodeNS",
    proc(this: JSValue) =
      let namespace = &runtime.argument(1, required = true)
      let localName = &runtime.argument(2, required = true)
      ret getAttributeNodeNS(
        rt = runtime, this = this, namespace = namespace, localName = localName
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "setAttributeNode",
    proc(this: JSValue) =
      let attr = &runtime.argument(1, required = true)
      ret setAttributeNode(rt = runtime, this = this, attr = attr)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "setAttributeNodeNS",
    proc(this: JSValue) =
      let attr = &runtime.argument(1, required = true)
      ret setAttributeNodeNS(rt = runtime, this = this, attr = attr)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "removeAttributeNode",
    proc(this: JSValue) =
      let attr = &runtime.argument(1, required = true)
      ret removeAttributeNode(rt = runtime, this = this, attr = attr)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "attachShadow",
    proc(this: JSValue) =
      let init = &runtime.argument(1, required = true)
      ret attachShadow(rt = runtime, this = this, init = init)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "closest",
    proc(this: JSValue) =
      let selectors = &runtime.argument(1, required = true)
      ret closest(rt = runtime, this = this, selectors = selectors)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "matches",
    proc(this: JSValue) =
      let selectors = &runtime.argument(1, required = true)
      ret matches(rt = runtime, this = this, selectors = selectors)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "webkitMatchesSelector",
    proc(this: JSValue) =
      let selectors = &runtime.argument(1, required = true)
      ret webkitMatchesSelector(rt = runtime, this = this, selectors = selectors)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "getElementsByTagName",
    proc(this: JSValue) =
      let qualifiedName = &runtime.argument(1, required = true)
      ret getElementsByTagName(rt = runtime, this = this, qualifiedName = qualifiedName)
    ,
  )

  runtime.definePrototypeFn(
    Element,
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
    Element,
    "getElementsByClassName",
    proc(this: JSValue) =
      let classNames = &runtime.argument(1, required = true)
      ret getElementsByClassName(rt = runtime, this = this, classNames = classNames)
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "insertAdjacentElement",
    proc(this: JSValue) =
      let where = &runtime.argument(1, required = true)
      let element = &runtime.argument(2, required = true)
      ret insertAdjacentElement(
        rt = runtime, this = this, where = where, element = element
      )
    ,
  )

  runtime.definePrototypeFn(
    Element,
    "insertAdjacentText",
    proc(this: JSValue) =
      let where = &runtime.argument(1, required = true)
      let data = &runtime.argument(2, required = true)
      ret insertAdjacentText(rt = runtime, this = this, where = where, data = data)
    ,
  )
