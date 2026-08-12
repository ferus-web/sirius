## GTK4 browser shell implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, posix]
import pkg/[shakar, chronicles]
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

  frameAcked: bool
  bufferFd*: int32

proc updateBufferFd*(state: BrowserState, fd: int32) =
  state.bufferFd = fd
  echo "updateBufferFd " & $fd
  let builder = gdk_dmabuf_texture_builder_new()
  gdk_dmabuf_texture_builder_set_display(builder, gdk_display_get_default())

  gdk_dmabuf_texture_builder_set_width(builder, 640'u32)
  gdk_dmabuf_texture_builder_set_height(builder, 480'u32)
  gdk_dmabuf_texture_builder_set_fourcc(builder, DRM_FORMAT_ABGR8888)
  gdk_dmabuf_texture_builder_set_modifier(builder, DRM_FORMAT_MOD_LINEAR)

  gdk_dmabuf_texture_builder_set_fd(builder, 0, fd)
  gdk_dmabuf_texture_builder_set_stride(builder, 0, uint32(640 * 4))
  gdk_dmabuf_texture_builder_set_offset(builder, 0, 0)

  var err: pointer
  let texture = gdk_dmabuf_texture_builder_build(builder, nil, nil, err.addr)

  if texture != nil:
    gtk_picture_set_paintable(state.viewport, texture)
    g_object_unref(texture)
  else:
    assert off

  g_object_unref(builder)
  # discard posix.close(fd)

proc onFrameTick(
    widget: ptr EGtkWidget, frameClock: ptr GdkFrameClock, userData: pointer
): int32 {.cdecl.} =
  let browser = cast[BrowserState](userData)

  if browser.frameAcked:
    # debugecho "send drawFrame call"
    browser.view.master.drawFrame(&browser.view.master.tabs[0].renderer())
    browser.frameAcked = false

  gtk_widget_queue_draw(widget)

  return G_SOURCE_CONTINUE

proc onActivate(app: ptr AdwApplication, userData: pointer) {.cdecl.} =
  let browser = cast[BrowserState](userData)

  browser.window = adw_application_window_new(app)
  gtk_window_set_default_size(browser.window, 640, 480)

  let mainBox = gtk_box_new(1, 0)
  adw_application_window_set_content(browser.window, mainBox)

  let headerBar = adw_header_bar_new()
  let windowTitle = adw_window_title_new("Sirius", "")
  adw_header_bar_set_title_widget(headerBar, windowTitle)
  gtk_box_append(mainBox, headerBar)

  browser.viewport = gtk_picture_new()

  discard gtk_widget_add_tick_callback(
    browser.viewport, onFrameTick, cast[pointer](browser), nil
  )

  gtk_box_append(mainBox, browser.viewport)
  gtk_window_present(browser.window)

proc sourceFn(state: BrowserState, fd: int32) =
  let msgOpt = state.view.master.blockForMessage(MasterOp, fd = some(fd))
  if !msgOpt:
    warn "Received invalid message, ignoring", sender = fd
    return

  let msg = &msgOpt
  case msg.op
  of MasterOp.FrameDrawn:
    state.frameAcked = true
  of MasterOp.UseGraphicsFD:
    let fd = &msg.fd(0)
    state.updateBufferFd(fd)

proc startBrowserShell*(view: WebView) =
  let browser = BrowserState(view: view, frameAcked: true, bufferFd: -1)
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
