## GTK4 browser shell implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, posix, strformat, strutils, unicode]
import pkg/[shakar, results, chronicles, vmath, url]
import
  components/synapse/[decoder, master, types, transport/socketpairs],
  components/synapse/descriptors/[master],
  components/impure/gtk
import components/css/types
import ../webview/[core, types], ../argparser

logScope:
  topics = "browser/app"

type BrowserState = ref object
  view: WebView

  window: ptr EGtkWidget
  viewport: ptr EGtkWidget
  urlBar: ptr EGtkWidget

  tabs: seq[TabID]
  tab: TabID

  frameAcked: bool

  viewportSize: vmath.IVec2
  scrollDelta: vmath.Vec2

proc userNavigationRequest(state: BrowserState, target: string) =
  # TODO: Document the algorithm behind this somewhere

  # 1. If `target` can be parsed as a URL with no errors, the happy path is to be executed: navigate directly to its parsed representation.
  let parsedHappy = tryParseURL(target)
  if *parsedHappy:
    state.view.loadURL(state.tab, &parsedHappy)
    return

  template navigateTo(src: string) =
    let parsed = tryParseURL(src)
    if *parsed:
      state.view.loadURL(state.tab, &parsed)
      return

  # 2. Otherwise, try to correct the input as per the error observed during initial parsing. This is mostly based off of my inference as to where most people go wrong (or even just slightly off) while typing URLs :P
  # a. If the scheme is missing, prepend "https://" to the URL.
  if parsedHappy.error() == ParseError.MissingSchemeNonRelativeUrl:
    navigateTo &"https://{target}"

  # TODO: maybe there are other common gotchas we could add here?

  # 3. If all normalization attempts fail, navigate to the user's preferred search engine,
  # with `target` becoming the search query.

  # TODO: do that.

proc reconstructViewport(state: BrowserState) =
  if state.view.bufferFd < 0:
    return

  if state.viewportSize.x <= 0 or state.viewportSize.y <= 0:
    return

  let builder = gdk_dmabuf_texture_builder_new()
  gdk_dmabuf_texture_builder_set_display(builder, gdk_display_get_default())

  gdk_dmabuf_texture_builder_set_width(builder, uint32(state.viewportSize.x))
  gdk_dmabuf_texture_builder_set_height(builder, uint32(state.viewportSize.y))
  gdk_dmabuf_texture_builder_set_fourcc(builder, DRM_FORMAT_ABGR8888)
  gdk_dmabuf_texture_builder_set_modifier(builder, DRM_FORMAT_MOD_LINEAR)

  gdk_dmabuf_texture_builder_set_fd(builder, 0, state.view.bufferFd)
  gdk_dmabuf_texture_builder_set_stride(builder, 0, state.view.bufferStride)
  gdk_dmabuf_texture_builder_set_offset(builder, 0, 0)

  var err: pointer
  let texture = gdk_dmabuf_texture_builder_build(builder, nil, nil, err.addr)

  if texture != nil:
    gtk_picture_set_paintable(state.viewport, texture)
    g_object_unref(texture)

  g_object_unref(builder)

proc onFrameTick(
    widget: ptr EGtkWidget, frameClock: ptr GdkFrameClock, userData: pointer
): int32 {.cdecl.} =
  let browser = cast[BrowserState](userData)
  let currSize = ivec2(gtk_widget_get_width(widget), gtk_widget_get_height(widget) + 1)

  if currSize.x == 0 or currSize.y == 0:
    return G_SOURCE_CONTINUE

  # echo currSize
  if currSize != browser.viewportSize:
    browser.view.master.resizeRenderTarget(
      &browser.view.master.tabs[0].renderer(), currSize
    )
    # browser.updateBufferFd(browser.bufferFd)

  if browser.frameAcked:
    browser.view.master.drawFrame(&browser.view.master.tabs[0].renderer())
    browser.frameAcked = false

  if browser.scrollDelta.x != 0'f32 or browser.scrollDelta.y != 0'f32:
    # TODO: maybe if only one of them (likely) got changed, we can only send the one
    # changed via specialized horizontal/vertical IPC calls so we only ship one f32 instead
    # of two, even when not required?
    browser.view.master.scrollViewport(0, browser.scrollDelta)
    browser.scrollDelta.reset()

  gtk_widget_queue_draw(widget)
  browser.view.step()

  return G_SOURCE_CONTINUE

proc onScroll(widget: ptr EGtkWidget, dx, dy: float64, userData: pointer) {.cdecl.} =
  let browser = cast[BrowserState](userData)
  browser.scrollDelta += vec2(dx, dy)

proc onCursorMotion(
    widget: ptr EGtkWidget, x, y: float64, userData: pointer
) {.cdecl.} =
  let browser = cast[BrowserState](userData)
  browser.view.master.cursorMotion(browser.tab, vec2(x, y))

proc onCursorClick(
    widget: ptr EGtkWidget, nPress: int32, x, y: float64, userData: pointer
) {.cdecl.} =
  let browser = cast[BrowserState](userData)
  browser.view.master.cursorClick(browser.tab)

proc keyvalToDomKey(keyval: uint32): string =
  if keyval == GDK_KEY_Return or keyval == GDK_KEY_KP_Enter:
    return "Enter"
  elif keyval == GDK_KEY_Escape:
    return "Escape"
  elif keyval == GDK_KEY_BackSpace:
    return "Backspace"
  elif keyval == GDK_KEY_Tab:
    return "Tab"
  elif keyval == GDK_KEY_Up:
    return "ArrowUp"
  elif keyval == GDK_KEY_Down:
    return "ArrowDown"
  elif keyval == GDK_KEY_Left:
    return "ArrowLeft"
  elif keyval == GDK_KEY_Right:
    return "ArrowRight"
  elif keyval == GDK_KEY_Shift_L or keyval == GDK_KEY_Shift_R:
    return "Shift"
  elif keyval == GDK_KEY_Control_L or keyval == GDK_KEY_Control_R:
    return "Control"
  elif keyval == GDK_KEY_Alt_L or keyval == GDK_KEY_Alt_R:
    return "Alt"
  else:
    let codepoint = gdk_keyval_to_unicode(keyval)
    if codepoint >= 0x20'u32 and codepoint != 0x7f'u32:
      return $Rune(codepoint)

    "Unidentified"

proc onKeyPress(
    widget: ptr EGtkWidget,
    keyval: uint32,
    keycode: uint32,
    state: uint32,
    userData: pointer,
): int32 {.cdecl.} =
  let browser = cast[BrowserState](userData)

  browser.view.master.pressKey(
    tab = browser.tab,
    key = keyvalToDomKey(keyval),
    keycode = newString(0), # TODO
    repeat = false,
  )

proc onActivate(app: ptr AdwApplication, userData: pointer) {.cdecl.} =
  let browser = cast[BrowserState](userData)

  browser.window = adw_application_window_new(app)
  gtk_window_set_default_size(browser.window, 640, 480)

  let mainBox = gtk_box_new(1, 0)
  adw_application_window_set_content(browser.window, mainBox)

  let headerBar = adw_header_bar_new()

  browser.urlBar = gtk_entry_new()
  gtk_entry_set_placeholder_text(browser.urlBar, "Enter URL")
  gtk_widget_set_size_request(browser.urlBar, 400, -1)
  gtk_widget_set_hexpand(browser.urlBar, true)
  gtk_widget_set_vexpand(browser.urlBar, false)

  discard g_signal_connect_data(
    browser.urlBar,
    "activate",
    cast[pointer](proc(entry: ptr EGtkWidget, userData: pointer) {.cdecl.} =
      let browser = cast[BrowserState](userData)
      let urlPtr = $gtk_editable_get_text(entry)

      browser.userNavigationRequest(urlPtr)),
    cast[pointer](browser),
    nil,
    0,
  )

  adw_header_bar_set_title_widget(headerBar, browser.urlBar)

  # let windowTitle = adw_window_title_new("Sirius", "")
  # adw_header_bar_set_title_widget(headerBar, windowTitle)
  gtk_box_append(mainBox, headerBar)

  # browser.headerBar = headerBar
  browser.viewport = gtk_picture_new()
  gtk_widget_set_hexpand(browser.viewport, true)
  gtk_widget_set_vexpand(browser.viewport, true)
  gtk_picture_set_can_shrink(browser.viewport, true)

  gtk_widget_set_focusable(browser.viewport, true)

  let scrollCtrl = gtk_event_controller_scroll_new(3)
  discard g_signal_connect_data(
    scrollCtrl, "scroll", cast[pointer](onScroll), cast[pointer](browser), nil, 0
  )
  gtk_widget_add_controller(browser.viewport, scrollCtrl)

  let motionCtrl = gtk_event_controller_motion_new()
  discard g_signal_connect_data(
    motionCtrl, "motion", cast[pointer](onCursorMotion), cast[pointer](browser), nil, 0
  )
  gtk_widget_add_controller(browser.viewport, motionCtrl)

  discard gtk_widget_add_tick_callback(
    browser.viewport, onFrameTick, cast[pointer](browser), nil
  )

  let clickGest = gtk_gesture_click_new()
  gtk_gesture_single_set_button(clickGest, GDK_BUTTON_PRIMARY)
  discard g_signal_connect_data(
    clickGest, "pressed", cast[pointer](onCursorClick), cast[pointer](browser), nil, 0
  )
  gtk_widget_add_controller(browser.viewport, clickGest)

  let keyCtrl = gtk_event_controller_key_new()
  discard g_signal_connect_data(
    keyCtrl, "key-pressed", cast[pointer](onKeyPress), cast[pointer](browser), nil, 0
  )
  gtk_widget_add_controller(browser.viewport, keyCtrl)

  gtk_box_append(mainBox, browser.viewport)
  gtk_window_present(browser.window)

  discard gtk_widget_grab_focus(browser.viewport)

proc setPageTitle(browser: BrowserState, title: string) =
  gtk_window_set_title(browser.window, &"{title.strip()} — Sirius")

proc setPCursorShape*(browser: BrowserState, predef: CursorPredefined) =
  gtk_widget_set_cursor_from_name(browser.viewport, cstring($predef))

proc showDeadTabPage(browser: BrowserState) =
  let parentBox = gtk_widget_get_parent(browser.viewport)
  if parentBox == nil:
    return

  gtk_box_remove(parentBox, browser.viewport)

  let crashBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 24)
  gtk_widget_set_hexpand(crashBox, true)
  gtk_widget_set_vexpand(crashBox, true)

  gtk_widget_set_halign(crashBox, GTK_ALIGN_CENTER)
  gtk_widget_set_valign(crashBox, GTK_ALIGN_CENTER)

  let icon = gtk_image_new_from_icon_name("computer-fail-symbolic")
  gtk_image_set_pixel_size(icon, 128)
  gtk_widget_add_css_class(icon, "dim-label")
  gtk_box_append(crashBox, icon)

  let label = gtk_label_new("Your tab crashed. Oopsies.")
  gtk_widget_add_css_class(label, "title-2")
  gtk_box_append(crashBox, label)

  gtk_box_append(parentBox, crashBox)

  browser.setPageTitle("Oopsies.")

proc handleDeadChild(state: BrowserState, tab: TabID, process: Process) =
  warn "Process has died unexpectedly.",
    tab = tab, kind = process.kind, channel = process.fd

  case process.kind
  of ProcessKind.Renderer:
    if tab == state.tab:
      # TODO: whenever we get tabbed browsing, we should probably track this properly
      # TODO: also, maybe we should try to recover the renderer in the future?

      showDeadTabPage(state)
  else:
    unreachable

proc showAlertMessage(state: BrowserState, message: Option[string]) =
  let text =
    if *message:
      &message
    else:
      newString(0)

  let dialog = adw_alert_dialog_new(
    "This page says:",
      # TODO: Tab should prooobably track the current URL where its renderer is at.
    text.cstring,
  )

  adw_alert_dialog_add_response(dialog, "ok", "OK")

  adw_alert_dialog_set_default_response(dialog, "ok")
  adw_alert_dialog_set_close_response(dialog, "ok")

  #[ discard g_signal_connect_data(
    dialog, "response", cast[pointer](onAlertDismissed), cast[pointer](state), nil, 0
  )]#

  adw_dialog_present(dialog, state.window)

proc attachIPCEventHandlers(state: BrowserState) =
  state.view.onFrameDrawn = proc(view: WebView, tab: TabID) =
    state.frameAcked = true
    state.reconstructViewport()

  state.view.onReconstruct = proc(view: WebView, tab: TabID) =
    state.reconstructViewport()

  state.view.onResize = proc(view: WebView, tab: TabID, size: vmath.IVec2) =
    info "Render target resized", size = size, stride = view.bufferStride
    state.viewportSize = size

  state.view.onProcessFault = proc(view: WebView, tab: TabID, process: Process) =
    state.handleDeadChild(tab, process)

  state.view.onPageTitleChange = proc(view: WebView, tab: TabID, title: string) =
    state.setPageTitle(title)

  state.view.onSetCursorShape = proc(
      view: WebView, tab: TabID, predef: CursorPredefined
  ) =
    state.setPCursorShape(predef)

  state.view.onAlert = proc(view: WebView, tab: TabID, msg: Option[string]) =
    state.showAlertMessage(msg)

proc startBrowserShell*(view: WebView, args: argparser.Input) =
  let browser =
    BrowserState(view: view, frameAcked: true, viewportSize: ivec2(640, 480))
  let app = adw_application_new("xyz.xtrayambak.sirius", 0)

  discard g_signal_connect_data(
    app, "activate", cast[pointer](onActivate), cast[pointer](browser), nil, 0
  )

  # TODO: do this for every tab that we have once we have that working
  let tab = browser.view.createTab()

  browser.tabs &= tab
  browser.tab = tab
  attachIPCEventHandlers(browser)

  if args.command.len > 0:
    view.loadURL(tab, tryParseURL(args.command).valueOr(parseURL("sirius:new")))

  discard g_application_run(app, 0, nil)
  g_object_unref(app)
