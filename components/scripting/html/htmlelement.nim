import
  components/js/runtime/prelude, components/scripting/dom/element, components/dom/dom
import pkg/[chronicles, shakar]

logScope:
  topics = "html/element"

type HTMLElement* = object of element.Element

proc titleGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.title getter"
  undefined(rt)

proc titleSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.title setter"

proc langGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.lang getter"
  undefined(rt)

proc langSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.lang setter"

proc translateGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.translate getter"
  undefined(rt)

proc translateSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.translate setter"

proc dirGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.dir getter"
  undefined(rt)

proc dirSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.dir setter"

proc hiddenGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.hidden getter"
  undefined(rt)

proc hiddenSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.hidden setter"

proc inertGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.inert getter"
  undefined(rt)

proc inertSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.inert setter"

proc accessKeyGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.accessKey getter"
  undefined(rt)

proc accessKeySetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.accessKey setter"

proc accessKeyLabelGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.accessKeyLabel getter"
  undefined(rt)

proc draggableGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.draggable getter"
  undefined(rt)

proc draggableSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.draggable setter"

proc spellcheckGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.spellcheck getter"
  undefined(rt)

proc spellcheckSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.spellcheck setter"

proc writingSuggestionsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.writingSuggestions getter"
  undefined(rt)

proc writingSuggestionsSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.writingSuggestions setter"

proc autocapitalizeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.autocapitalize getter"
  undefined(rt)

proc autocapitalizeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.autocapitalize setter"

proc autocorrectGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.autocorrect getter"
  undefined(rt)

proc autocorrectSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.autocorrect setter"

proc innerTextGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.innerText getter"
  undefined(rt)

proc innerTextSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.innerText setter"

proc outerTextGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.outerText getter"
  undefined(rt)

proc outerTextSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.outerText setter"

proc popoverGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.popover getter"
  undefined(rt)

proc popoverSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.popover setter"

proc headingOffsetGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.headingOffset getter"
  undefined(rt)

proc headingOffsetSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.headingOffset setter"

proc headingResetGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement.headingReset getter"
  undefined(rt)

proc headingResetSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: HTMLElement.headingReset setter"

proc click(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement::click()"
  undefined(rt)

proc attachInternals(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement::attachInternals()"
  undefined(rt)

proc showPopover(rt: Runtime, this: JSValue, options: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement::showPopover()", options = rt.ToString(options)
  undefined(rt)

proc hidePopover(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement::hidePopover()"
  undefined(rt)

proc togglePopover(rt: Runtime, this: JSValue, options: JSValue): JSValue =
  warn "IMPLEMENTME: HTMLElement::togglePopover()", options = rt.ToString(options)
  undefined(rt)

proc toHTMLElement*(runtime: Runtime, element: dom.Element): JSValue =
  let elem = runtime.createObjFromType(HTMLElement)
  elem.setHiddenField("internal", runtime.wrap(hidden(dom.Node(element))))

  elem

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("HTMLElement", HTMLElement)
  runtime.defineAccessor(
    HTMLElement,
    "title",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret titleGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        titleSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "lang",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret langGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        langSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "translate",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret translateGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        translateSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "dir",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret dirGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        dirSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "hidden",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret hiddenGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        hiddenSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "inert",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret inertGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        inertSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "accessKey",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret accessKeyGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        accessKeySetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "accessKeyLabel",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret accessKeyLabelGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "draggable",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret draggableGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        draggableSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "spellcheck",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret spellcheckGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        spellcheckSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "writingSuggestions",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret writingSuggestionsGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        writingSuggestionsSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "autocapitalize",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret autocapitalizeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        autocapitalizeSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "autocorrect",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret autocorrectGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        autocorrectSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "innerText",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret innerTextGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        innerTextSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "outerText",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret outerTextGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        outerTextSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "popover",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret popoverGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        popoverSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "headingOffset",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret headingOffsetGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        headingOffsetSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    HTMLElement,
    "headingReset",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret headingResetGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        headingResetSetter(rt = runtime, this, value),
    ),
  )

  runtime.definePrototypeFn(
    HTMLElement,
    "click",
    proc(this: JSValue) =
      ret click(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    HTMLElement,
    "attachInternals",
    proc(this: JSValue) =
      ret attachInternals(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    HTMLElement,
    "showPopover",
    proc(this: JSValue) =
      let options = &runtime.argument(1, required = false)
      ret showPopover(rt = runtime, this = this, options = options)
    ,
  )

  runtime.definePrototypeFn(
    HTMLElement,
    "hidePopover",
    proc(this: JSValue) =
      ret hidePopover(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    HTMLElement,
    "togglePopover",
    proc(this: JSValue) =
      let options = &runtime.argument(1, required = false)
      ret togglePopover(rt = runtime, this = this, options = options)
    ,
  )
