## DOM mutation algorithm implementations.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import components/dom/dom, components/html/parser
import pkg/[results, shakar]

func findParentIndex(node: dom.Node): uint =
  ## Find the index at which the node resides in its parent's children-list.
  ##
  ## **NOTE**: It is up to the caller to verify that parentNode is not nil. This function will simply panic otherwise.
  assert(
    node.parentNode != nil,
    "Bug: DOM: Node::findParentIndex() will not work with nodes with no parent. Guard the call point properly.",
  )

  let nodeParentIndex = node.parentNode.childList.find(node)
  assert(
    nodeParentIndex >= 0,
    "Invariant: DOM: Node::findParentIndex() got a node whose parent does not acknowledge it as a child!",
  )

  uint(nodeParentIndex)

# TODO: Move these getters elsewhere somewhere in components::dom
func previousSibling*(node: dom.Node): Option[dom.Node] =
  ## The previous sibling of an object is its first preceding sibling or null if it has no preceding sibling. 
  if node.parentNode == nil:
    return none(dom.Node)

  let nodeParentIndex = findParentIndex(node)
  if nodeParentIndex == 0:
    return none(dom.Node)

  some(node.parentNode.childList[nodeParentIndex - 1])

func nextSibling*(node: dom.Node): Option[dom.Node] =
  ## The next sibling of an object is its first following sibling or null if it has no following sibling.
  if node.parentNode == nil:
    return none(dom.Node)

  let nodeParentIndex = findParentIndex(node)
  if nodeParentIndex + 1 == uint(node.parentNode.childList.len):
    return none(dom.Node)

  some(node.parentNode.childList[nodeParentIndex + 1])

func lastChild*(node: dom.Node): Option[dom.Node] =
  ## The last child of an object is its last child or null if it has no children. 
  if node.childList.len < 1:
    return none(dom.Node)

  some(node.childList[^1])

{.push discardable.}
proc removeChild*(parent: dom.Node, node: dom.Node): Result[void, string] =
  # To remove a node node, with an optional boolean suppressObservers (default false): 
  # debugEcho &"Node::removeChild(parent=0x{cast[uint64](parent):X}, node=0x{cast[uint64](node):X})"

  # 1. Let parent be node’s parent.
  # 2. Assert: parent is non-null. 
  assert(parent != nil)

  # TODO: 3. Run the live range pre-remove steps, given node. 
  # TODO: 4. For each NodeIterator object iterator whose root’s node document is node’s node document: run the NodeIterator pre-remove steps given node and iterator. 
  discard

  # 5. Let oldPreviousSibling be node’s previous sibling.
  let oldPreviousSibling = node.previousSibling

  # 6. Let oldNextSibling be node’s next sibling. 
  let oldNextSibling = node.nextSibling

  # 7. Remove node from its parent’s children. 
  # OPTIMIZE: Maybe we could cache the output of findParentIndex? Just here itself we're calling it like three times already. That's mostly food for thought for now though, I doubt the invalidation will be fun.
  node.parentNode.childList.delete(findParentIndex(node))
  node.parentNode = nil

  # TODO: Implement the remaining steps
  # 8. If node is assigned, then run assign slottables for node’s assigned slot.
  # 9. If parent’s root is a shadow root, and parent is a slot whose assigned nodes is the empty list, then run signal a slot change for parent. 
  # 10. If node has an inclusive descendant that is a slot:
  #   1. Run assign slottables for a tree with parent’s root. 
  #   2. Run assign slottables for a tree with node. 
  # 11. Run the removing steps with node, true, and parent. 
  # 12. Let isParentConnected be parent’s connected. 
  # 13. If node is custom and isParentConnected is true, then enqueue a custom element callback reaction with node, callback name "disconnectedCallback", and « ». 
  # 14. For each shadow-including descendant descendant of node, in shadow-including tree order:
  #  1. Run the removing steps with descendant, false, and parent. 
  #  2. If descendant is custom and isParentConnected is true, then enqueue a custom element callback reaction with descendant, callback name "disconnectedCallback", and « ». 
  # 15. For each inclusive ancestor inclusiveAncestor of parent, and then for each registered of inclusiveAncestor’s registered observer list, if registered’s options["subtree"] is true, then append a new transient registered observer whose observer is registered’s observer, options is registered’s options, and source is registered to node’s registered observer list.
  # 16. If suppressObservers is false, then queue a tree mutation record for parent with « », « node », oldPreviousSibling, and oldNextSibling.
  # 17. Run the children changed steps for parent.

  ok()

proc insert*(parent: dom.Node, node: dom.Node, before: dom.Node) =
  # To insert a node node into a node parent before null or a node child, with an optional boolean suppressObservers (default false): 
  # debugEcho &"Node::insert(parent=0x{cast[uint64](parent):X}, node=0x{cast[uint64](node):X}, before=0x{cast[uint64](before):X}"

  # 1. Let nodes be node’s children, if node is a DocumentFragment node; otherwise « node ».
  let nodes =
    if node of dom.DocumentFragment:
      node.childList
    else:
      @[node]

  # 2. Let count be nodes’s size.
  let count = nodes.len

  # 3. If count is 0, then return. 
  if count < 1:
    return

  # 4. If node is a DocumentFragment node: 
  if node of dom.DocumentFragment:
    # 1. Remove its children with suppressObservers set to true. 
    while node.childList.len > 0:
      node.removeChild(node.childList[0])

    # TODO: 2. Queue a tree mutation record for node with « », nodes, null, and null.
    discard

  # 5. If child is non-null:
  if before != nil:
    # TODO: 1. For each live range whose start node is parent and start offset is greater than child’s index: increase its start offset by count.
    # TODO: 2. For each live range whose end node is parent and end offset is greater than child’s index: increase its end offset by count. 
    discard

  # 6. Let previousSibling be child’s previous sibling or parent’s last child if child is null. 
  let prevSibling = if before != nil: before.previousSibling else: parent.lastChild

  # 7. For each node in nodes, in tree order: 
  for nodeObj in nodes:
    # TODO: 1. Adopt node into parent’s node document.
    discard

    if before == nil:
      # 2. If child is null, then append node to parent’s children. 
      parent.childList &= nodeObj
    else:
      # 3. Otherwise, insert node into parent’s children before child’s index. 
      parent.childList.insert(nodeObj, findParentIndex(before))
        # OPTIMIZE: Cache `findParentIndex()`'s output outside this loop

    # TODO: 4. If parent is a shadow host whose shadow root’s slot assignment is "named" and node is a slottable, then assign a slot for node.
    # 5. If parent’s root is a shadow root, and parent is a slot whose assigned nodes is the empty list, then run signal a slot change for parent.
    # 6. Run assign slottables for a tree with node’s root.
    # 7. For each shadow-including inclusive descendant inclusiveDescendant of node, in shadow-including tree order: 
    #  1. Run the insertion steps with inclusiveDescendant. 
    #  2. If inclusiveDescendant is not connected, then continue.
    #  3. If inclusiveDescendant is an element and inclusiveDescendant’s custom element registry is non-null:
    #    1. If inclusiveDescendant’s custom element registry’s is scoped is true, then append inclusiveDescendant’s node document to inclusiveDescendant’s custom element registry’s scoped document set. 
    #    2. If inclusiveDescendant is custom, then enqueue a custom element callback reaction with inclusiveDescendant, callback name "connectedCallback", and « ». 
    #    3. Otherwise, try to upgrade inclusiveDescendant. 
    #  4. Otherwise, if inclusiveDescendant is a shadow root, inclusiveDescendant’s custom element registry is non-null, and inclusiveDescendant’s custom element registry’s is scoped is true, then append inclusiveDescendant’s node document to inclusiveDescendant’s custom element registry’s scoped document set.
    discard

  # TODO: # 8. If suppressObservers is false, then queue a tree mutation record for parent with nodes, « », previousSibling, and child. 
  # 9. Run the children changed steps for parent. 
  # 10. Let staticNodeList be a list of nodes, initially « ». 
  # 11. For each node of nodes, in tree order: 
  #   1. For each shadow-including inclusive descendant inclusiveDescendant of node, in shadow-including tree order: append inclusiveDescendant to staticNodeList. 
  # 12. For each node of staticNodeList: if node is connected, then run the post-connection steps with node. 
  discard

proc preInsert*(
    parent: dom.Node, node: dom.Node, child: dom.Node
): Result[dom.Node, string] =
  ## https://dom.spec.whatwg.org/#concept-node-pre-insert
  # debugEcho &"Node::preInsert(parent=0x{cast[uint64](parent):X}, node=0x{cast[uint64](node):X}, child=0x{cast[uint64](child):X})"

  # To pre-insert a node node into a node parent before null or node child: 

  # 1. Ensure pre-insert validity given node, parent, child, and « ».
  if not preInsertionValidity(parent = parent, node = node, before = child):
    return err("Cannot pre-insert: parent node failed validity test")

  # 2. Let referenceChild be child. 
  var referenceChild = child

  # 3. If referenceChild is node, then set referenceChild to node’s next sibling. 
  if referenceChild == node:
    referenceChild = &referenceChild.nextSibling

  # 4. Insert node into parent before referenceChild.
  # NOTE: This checks for pre-insertion validity again. Maybe we could pass it a flag to not do so.
  parent.insertBefore(
    node,
    before =
      if referenceChild != nil:
        some(referenceChild)
      else:
        none(dom.Node),
  )
  markDirty(node)

  # 5. Return node.
  ok(node)

proc append*(parent: dom.Node, node: dom.Node): Result[dom.Node, string] =
  # debugEcho &"Node::append(parent=0x{cast[uint64](parent):X}, node=0x{cast[uint64](node):X})"
  # To append a node node to a node parent: pre-insert node into parent before null.
  parent.preInsert(node, nil)

{.pop.}
