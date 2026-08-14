## Some bindings for GTK4/libadwaita/GLib
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
{.passC: gorge("pkg-config --cflags gtk4 libadwaita-1").}
{.passL: gorge("pkg-config --libs gtk4 libadwaita-1").}

{.push header: "<glib-unix.h>".}
type
  GUnixFDSourceFunc* =
    proc(fd: int32, condition: GIOCondition, userData: pointer): int32 {.cdecl.}

  GIOCondition* {.importc: "GIOCondition".} = distinct int32

{.push importc.}
let
  G_IO_IN*: GIOCondition
  G_IO_OUT*: GIOCondition
  G_IO_ERR*: GIOCOndition
  G_IO_HUP*: GIOCondition

proc g_unix_fd_add*(
  fd: int32, condition: GIOCondition, fn: GUnixFDSourceFunc, userData: pointer
): uint32

{.pop.}
{.pop.}

{.push importc, header: "<gtk/gtk.h>".}
let
  G_SOURCE_CONTINUE*: int32
  G_SOURCE_REMOVE*: int32
  GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES*: int32

{.pop.}

{.push importc, header: "<drm/drm_fourcc.h>".}
let
  DRM_FORMAT_ABGR8888*: uint32
  DRM_FORMAT_MOD_LINEAR*: uint64
{.pop.}

{.push header: "<adwaita.h>".}

type
  EGtkWidget* {.importc: "GtkWidget", incompleteStruct.} = object
  AdwApplication* {.importc: "AdwApplication", incompleteStruct.} = object
  GdkFrameClock* {.importc: "GdkFrameClock", incompleteStruct.} = object
  GdkTexture* {.importc, incompleteStruct.} = object
  GdkDmabufTextureBuilder* {.importc, incompleteStruct.} = object

  GDestroyNotify* = proc(data: pointer) {.cdecl.}

  GtkTickCallback* = proc(
    widget: ptr EGtkWidget, frameClock: ptr GdkFrameClock, userData: pointer
  ): int32 {.cdecl.}

{.push importc.}
proc adw_application_new*(applicationId: cstring, flags: int32): ptr AdwApplication
proc adw_application_window_new*(app: ptr AdwApplication): ptr EGtkWidget
proc adw_header_bar_new*(): ptr EGtkWidget
proc adw_window_title_new*(title: cstring, subtitle: cstring): ptr EGtkWidget
proc adw_application_window_set_content*(win: ptr EGtkWidget, content: ptr EGtkWidget)
proc adw_header_bar_set_title_widget*(bar: ptr EGtkWidget, titleWidget: ptr EGtkWidget)

proc gtk_box_new*(orientation: int32, spacing: int32): ptr EGtkWidget
proc gtk_box_append*(box: ptr EGtkWidget, child: ptr EGtkWidget)
proc gtk_window_set_child*(window: ptr EGtkWidget, child: ptr EGtkWidget)
proc gtk_window_set_default_size*(window: ptr EGtkWidget, width: int32, height: int32)
proc gtk_window_set_title*(window: ptr EGtkWidget, title: cstring)
proc gtk_window_present*(window: ptr EGtkWidget)

proc gtk_widget_get_width*(widget: ptr EGtkWidget): int32
proc gtk_widget_get_height*(widget: ptr EGtkWidget): int32
proc gtk_widget_set_hexpand*(widget: ptr EGtkWidget, expand: bool)
proc gtk_widget_set_vexpand*(widget: ptr EGtkWidget, expand: bool)
proc gtk_picture_set_can_shrink*(picture: ptr EGtkWidget, canShrink: bool)

proc gtk_picture_new*(): ptr EGtkWidget
proc gtk_picture_set_paintable*(picture: ptr EGtkWidget, paintable: pointer)

proc gtk_entry_new*(): ptr EGtkWidget
proc gtk_entry_set_placeholder_text*(entry: ptr EGtkWidget, text: cstring)
proc gtk_editable_get_text*(editable: ptr EGtkWidget): cstring

proc gtk_widget_set_size_request*(widget: ptr EGtkWidget, h, v: int32)

proc gtk_widget_add_tick_callback*(
  widget: ptr EGtkWidget,
  callback: GtkTickCallback,
  userData: pointer,
  notify: GDestroyNotify,
): uint32

proc gtk_widget_queue_draw*(widget: ptr EGtkWidget)

proc g_signal_connect_data*(
  instance: pointer,
  detailedSignal: cstring,
  cHandler: pointer,
  data: pointer,
  destroyData: pointer,
  connectFlags: int32,
): culong

proc gtk_event_controller_scroll_new*(axes: int32): ptr EGtkWidget
proc gtk_widget_add_controller*(widget: ptr EGtkWidget, controller: ptr EGtkWidget)

proc g_application_run*(app: ptr AdwApplication, argc: int32, argv: ptr cstring): int32
proc g_object_unref*(obj: pointer)

proc gdk_display_get_default*(): pointer
proc gdk_dmabuf_texture_builder_new*(): ptr GdkDmabufTextureBuilder
proc gdk_dmabuf_texture_builder_set_display*(
  builder: ptr GdkDmabufTextureBuilder, display: pointer
)

proc gdk_dmabuf_texture_builder_set_width*(
  builder: ptr GdkDmabufTextureBuilder, width: uint32
)

proc gdk_dmabuf_texture_builder_set_height*(
  builder: ptr GdkDmabufTextureBuilder, height: uint32
)

proc gdk_dmabuf_texture_builder_set_fourcc*(
  builder: ptr GdkDmabufTextureBuilder, fourcc: uint32
)

proc gdk_dmabuf_texture_builder_set_modifier*(
  builder: ptr GdkDmabufTextureBuilder, modifier: uint64
)

proc gdk_dmabuf_texture_builder_set_fd*(
  builder: ptr GdkDmabufTextureBuilder, plane: uint32, fd: int32
)

proc gdk_dmabuf_texture_builder_set_stride*(
  builder: ptr GdkDmabufTextureBuilder, plane: uint32, stride: cuint
)

proc gdk_dmabuf_texture_builder_set_offset*(
  builder: ptr GdkDmabufTextureBuilder, plane: uint32, offset: cuint
)

proc gdk_dmabuf_texture_builder_build*(
  builder: ptr GdkDmabufTextureBuilder,
  destroy: pointer,
  data: pointer,
  error: ptr pointer,
): ptr GdkTexture

{.pop.}
{.pop.}

func `==`*(a, b: GIOCondition): bool {.borrow.}
func `or`*(a, b: GIOCondition): GIOCondition {.borrow.}
func `and`*(a, b: GIOCondition): GIOCondition {.borrow.}
