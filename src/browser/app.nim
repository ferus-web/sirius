## GTK4 browser shell implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, posix, strformat]
import pkg/[shakar, results, chronicles, vmath, url]
import
  components/synapse/[decoder, master, types, transport/socketpairs],
  components/synapse/descriptors/[master],
  components/impure/gtk
import ../webview/[core, types]

logScope:
  topics = "browser/app"

type BrowserState = ref object
  view: WebView

  window: ptr EGtkWidget
  viewport: ptr EGtkWidget
  urlBar: ptr EGtkWidget

  viewportSize*: vmath.IVec2

  frameAcked: bool

  bufferFd*: int32
  bufferStride*: uint32

  scrollDelta: vmath.Vec2

proc userNavigationRequest(state: BrowserState, target: string) =
  # TODO: Document the algorithm behind this somewhere

  # 1. If `target` can be parsed as a URL with no errors, the happy path is to be executed: navigate directly to its parsed representation.
  let parsedHappy = tryParseURL(target)
  if *parsedHappy:
    state.view.master.gotoURL(0, &parsedHappy)
    return

  template navigateTo(src: string) =
    let parsed = tryParseURL(src)
    if *parsed:
      state.view.master.gotoURL(0, &parsed)
      return

  # 2. Otherwise, try to correct the input as per the error observed during initial parsing. This is mostly based off of my inference as to where most people go wrong (or even just slightly off) while typing URLs :P
  # a. If the scheme is missing, prepend "https://" to the URL.
  if parsedHappy.error() == ParseError.MissingSchemeNonRelativeUrl:
    navigateTo &"https://{target}"

  # TODO: maybe there are other common gotchas we could add here?

  # 3. If all normalization attempts fail, navigate to the user's preferred search engine,
  # with `target` becoming the search query.

  # TODO: do that.

proc refreshViewport(state: BrowserState) =
  if state.bufferFd < 0:
    return

  let builder = gdk_dmabuf_texture_builder_new()
  gdk_dmabuf_texture_builder_set_display(builder, gdk_display_get_default())

  gdk_dmabuf_texture_builder_set_width(builder, uint32(state.viewportSize.x))
  gdk_dmabuf_texture_builder_set_height(builder, uint32(state.viewportSize.y))
  gdk_dmabuf_texture_builder_set_fourcc(builder, DRM_FORMAT_ABGR8888)
  gdk_dmabuf_texture_builder_set_modifier(builder, DRM_FORMAT_MOD_LINEAR)

  gdk_dmabuf_texture_builder_set_fd(builder, 0, state.bufferFd)
  gdk_dmabuf_texture_builder_set_stride(builder, 0, state.bufferStride)
  gdk_dmabuf_texture_builder_set_offset(builder, 0, 0)

  var err: pointer
  let texture = gdk_dmabuf_texture_builder_build(builder, nil, nil, err.addr)

  if texture != nil:
    gtk_picture_set_paintable(state.viewport, texture)
    g_object_unref(texture)

  g_object_unref(builder)

proc updateBufferFd*(state: BrowserState, fd: int32) =
  if fd < 0:
    return

  if state.bufferFd >= 0'i32:
    discard posix.close(state.bufferFd)

  state.bufferFd = fd
  state.refreshViewport()

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
    # debugecho "send drawFrame call"
    browser.view.master.drawFrame(&browser.view.master.tabs[0].renderer())
    browser.frameAcked = false

  if browser.scrollDelta.x != 0'f32 or browser.scrollDelta.y != 0'f32:
    # TODO: maybe if only one of them (likely) got changed, we can only send the one
    # changed via specialized horizontal/vertical IPC calls so we only ship one f32 instead
    # of two, even when not required?
    browser.view.master.scrollViewport(0, browser.scrollDelta)
    browser.scrollDelta.reset()

  gtk_widget_queue_draw(widget)

  return G_SOURCE_CONTINUE

proc onScroll(
    widget: ptr EGtkWidget, dx, dy: float64, userData: pointer
): bool {.cdecl.} =
  let browser = cast[BrowserState](userData)
  browser.scrollDelta += vec2(dx, dy)

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

  let scrollCtrl = gtk_event_controller_scroll_new(3)

  discard g_signal_connect_data(
    scrollCtrl, "scroll", cast[pointer](onScroll), cast[pointer](browser), nil, 0
  )

  gtk_widget_add_controller(browser.viewport, scrollCtrl)

  discard gtk_widget_add_tick_callback(
    browser.viewport, onFrameTick, cast[pointer](browser), nil
  )

  gtk_box_append(mainBox, browser.viewport)
  gtk_window_present(browser.window)

proc setPageTitle(browser: BrowserState, title: string) =
  gtk_window_set_title(browser.window, title)

proc sourceFn(state: BrowserState, fd: int32) =
  let msgOpt = state.view.master.blockForMessage(MasterOp, fd = some(fd))
  if !msgOpt:
    warn "Received invalid message, ignoring", sender = fd
    return

  # TODO: These should validate their arguments properly instead of just `get()`'ing them
  let msg = &msgOpt
  case msg.op
  of MasterOp.FrameDrawn:
    # debugecho "frame ack"
    state.frameAcked = true
    state.refreshViewport()
  of MasterOp.UseGraphicsFD:
    let fd = &msg.fd(0)
    state.updateBufferFd(fd)
  of MasterOp.TargetResized:
    let
      dims = &msg.argument(0, vmath.IVec2)
      stride = &msg.argument(1, uint32)
    info "Render target resized", dims = dims, stride = stride
    state.viewportSize = dims
    state.bufferStride = stride
  of MasterOp.SetPageTitle:
    state.setPageTitle(&msg.argument(0, string))

proc startBrowserShell*(view: WebView) =
  let browser = BrowserState(
    view: view, frameAcked: true, bufferFd: -1, viewportSize: ivec2(640, 480)
  )
  let app = adw_application_new("xyz.xtrayambak.sirius", 0)

  discard g_signal_connect_data(
    app, "activate", cast[pointer](onActivate), cast[pointer](browser), nil, 0
  )

  # TODO: do this for every tab that we have once we have that working
  let sourceFd = g_unix_fd_add(
    (&view.master.tabs[0].renderer()).fd,
    cast[GIOCondition](cast[int32](G_IO_IN) or cast[int32](G_IO_HUP)),
    proc(fd: int32, condition: GIOCondition, userData: pointer): int32 {.cdecl.} =
      sourceFn(cast[BrowserState](userData), fd)
      G_SOURCE_CONTINUE,
    cast[pointer](browser),
  )

  discard g_application_run(app, 0, nil)
  g_object_unref(app)
