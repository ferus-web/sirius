## Form encoding implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables]
import components/dom/[dom, tags], components/html/dom_utils
import pkg/[results, shakar], pkg/url/[unicode, views]

func collectControls(node: dom.Node, controls: var seq[dom.Element]) =
  if node of dom.Element:
    controls &= Element(node)

  for child in node.childList:
    collectControls(child, controls)

const FormURLPercentEncode*: array[32, uint8] = [
  uint8 0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x00 or 0x08 or 0x10 or 0x00 or 0x00 or 0x80,
  0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x00 or 0x08 or 0x10 or 0x20 or 0x40 or 0x00,
  0x01 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00 or 0x00,
  0x00 or 0x00 or 0x00 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
  0x01 or 0x02 or 0x04 or 0x08 or 0x10 or 0x20 or 0x40 or 0x80,
]

import components/aux/pretty

func disabled*(element: dom.Element): bool =
  ## https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#enabling-and-disabling-form-controls:-the-disabled-attribute

  # A form control is disabled if any of the following are true:

  # - the element is a button, input, select, textarea, or form-associated custom element, and the disabled attribute is specified on this element (regardless of its value); or
  if (
    let disabledAttr = element.getAttr(element.document.factory, "disabled")
    *disabledAttr
  ):
    return true

  # TODO: do this.
  # the element is a descendant of a fieldset element whose disabled attribute is specified, and the element is not a descendant of that fieldset element's first legend element child, if any.

  false

func encodeEntryList(entryList: Table[string, string]): string =
  ## https://url.spec.whatwg.org/#urlencoded-serializing
  var buffer = newStringOfCap(entryList.len * 8) # super scientific estimate

  # 3. For each tuple of tuples:
  for name, value in entryList:
    # 2. Let name be the result of running percent-encode after encoding with encoding, tuple’s name, and the application/x-www-form-urlencoded percent-encode set.
    let name = percentEncode(toStringView(name), FormURLPercentEncode)

    # 3. Let value be the result of running percent-encode after encoding with encoding, tuple’s value, and the application/x-www-form-urlencoded percent-encode set. 
    let value = percentEncode(toStringView(value), FormURLPercentEncode)

    # 4. If output is not the empty string, then append U+0026 (&) to output. 
    if buffer.len > 0:
      buffer &= '&'

    # 5. Append name, followed by U+003D (=), followed by value, to output.
    buffer &= name
    buffer &= '='
    buffer &= value

  # 4. Return output.
  ensureMove(buffer)

func collectAndEncodeForm*(form: tags.HTMLFormElement): Result[string, string] =
  ## https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#constructing-form-data-set

  # 1. If form's constructing entry list is true, then return null.
  # TODO.

  # 2. Set form's constructing entry list to true.
  # TODO.

  # 3. Let controls be a list of all the submittable elements whose form owner is form, in tree order.
  var controls = newSeqOfCap[dom.Element](form.childList.len)

  for child in form.childList:
    collectControls(child, controls)

  # 4. Let entry list be a new empty entry list.
  var entryList: Table[string, string]

  # 5. For each element field in controls, in tree order:
  for control in controls:
    # 1. If any of the following are true:
    # - field has a datalist element ancestor;
    # - field is disabled;
    # - field is a button but it is not submitter;
    # - field is an input element whose type attribute is in the Checkbox state and whose checkedness is false; or
    # - field is an input element whose type attribute is in the Radio Button state and whose checkedness is false,
    # then continue.
    if control.disabled:
      # TODO: Perform the remaining validations too.
      continue

    # TODO: Implement the 9 preceding cases :3

    # 10. Otherwise, create an entry with name and the value of the field element, and append it to entry list.
    if control of tags.HTMLInputElement:
      let input = HTMLInputElement(control)
      if *input.name:
        entryList[&input.name] = input.inputBuffer

  ok(encodeEntryList(ensureMove(entryList)))
