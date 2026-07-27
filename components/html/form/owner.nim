## Routines to associate input elements with their form owners.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options]
import components/dom/[dom, tags], components/html/dom_utils
import pkg/shakar

func findAncestorFormElement(start: dom.Element): Option[tags.HTMLFormElement] =
  # we basically just want to keep traversing up till we find a HTMLFormElement
  var curr: dom.Node = start.parentNode

  while curr != nil:
    if curr of tags.HTMLFormElement:
      return some(HTMLFormElement(curr))

    curr = curr.parentNode

  none(HTMLFormElement)

func resetFormOwner*(input: tags.HTMLInputElement): Option[tags.HTMLFormElement] =
  ## https://html.spec.whatwg.org/#association-of-controls-and-forms
  # To reset the form owner of a form-associated element element:

  # 1. Unset element's parser inserted flag.
  # 2. If all of the following are true:
  # - element's form owner is not null;
  # - element is not listed or its form content attribute is not present; and
  # - element's form owner is its nearest form element ancestor after the change to the ancestor chain,
  # then return.
  if *input.form:
    return input.form

  # 3. Set element's form owner to null.
  input.form = none(HTMLFormElement)

  # 4. If element is listed, has a form content attribute, and is connected:
  if (let formAttr = input.getAttr(input.document.factory, "form"); *formAttr):
    # 1. If the first element in element's tree, in tree order, to have an ID that is identical to element's form content attribute's value, is a form element, then associate the element with that form element.
    let owner = input.document.getElementById(input.document.factory, &formAttr)
    if *owner and &owner of tags.HTMLFormElement:
      input.form = some(HTMLFormElement(&owner))

    return

  # 5. Otherwise, if element has an ancestor form element, then associate element with the nearest such ancestor form element.
  findAncestorFormElement(input)
