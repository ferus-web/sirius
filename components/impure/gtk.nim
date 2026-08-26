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
  GTK_ORIENTATION_VERTICAL*: int32
  GTK_ALIGN_CENTER*: int32

  GDK_BUTTON_PRIMARY*: int32

  GDK_NO_MODIFIER_MASK*, GDK_SHIFT_MASK*, GDK_LOCK_MASK*, GDK_CONTROL_MASK*,
    GDK_ALT_MASK*, GDK_META_MASK*, GDK_SUPER_MASK*: uint32

  GDK_KEY_BackSpace*: uint32
  GDK_KEY_Tab*: uint32
  GDK_KEY_Linefeed*: uint32
  GDK_KEY_Clear*: uint32
  GDK_KEY_Return*: uint32
  GDK_KEY_Pause*: uint32
  GDK_KEY_Scroll_Lock*: uint32
  GDK_KEY_Sys_Req*: uint32
  GDK_KEY_Escape*: uint32
  GDK_KEY_Delete*: uint32
  GDK_KEY_ISO_Left_Tab*: uint32
  GDK_KEY_space*: uint32
  GDK_KEY_Home*: uint32
  GDK_KEY_Left*: uint32
  GDK_KEY_Up*: uint32
  GDK_KEY_Right*: uint32
  GDK_KEY_Down*: uint32
  GDK_KEY_Prior*: uint32
  GDK_KEY_Page_Up*: uint32
  GDK_KEY_Next*: uint32
  GDK_KEY_Page_Down*: uint32
  GDK_KEY_End*: uint32
  GDK_KEY_Begin*: uint32
  GDK_KEY_Select*: uint32
  GDK_KEY_Print*: uint32
  GDK_KEY_Execute*: uint32
  GDK_KEY_Insert*: uint32
  GDK_KEY_Undo*: uint32
  GDK_KEY_Redo*: uint32
  GDK_KEY_Menu*: uint32
  GDK_KEY_Find*: uint32
  GDK_KEY_Cancel*: uint32
  GDK_KEY_Help*: uint32
  GDK_KEY_Break*: uint32
  GDK_KEY_Mode_switch*: uint32
  GDK_KEY_Num_Lock*: uint32
  GDK_KEY_KP_Space*: uint32
  GDK_KEY_KP_Tab*: uint32
  GDK_KEY_KP_Enter*: uint32
  GDK_KEY_KP_F1*: uint32
  GDK_KEY_KP_F2*: uint32
  GDK_KEY_KP_F3*: uint32
  GDK_KEY_KP_F4*: uint32
  GDK_KEY_KP_Home*: uint32
  GDK_KEY_KP_Left*: uint32
  GDK_KEY_KP_Up*: uint32
  GDK_KEY_KP_Right*: uint32
  GDK_KEY_KP_Down*: uint32
  GDK_KEY_KP_Prior*: uint32
  GDK_KEY_KP_Page_Up*: uint32
  GDK_KEY_KP_Next*: uint32
  GDK_KEY_KP_Page_Down*: uint32
  GDK_KEY_KP_End*: uint32
  GDK_KEY_KP_Begin*: uint32
  GDK_KEY_KP_Insert*: uint32
  GDK_KEY_KP_Delete*: uint32
  GDK_KEY_KP_Equal*: uint32
  GDK_KEY_KP_Multiply*: uint32
  GDK_KEY_KP_Add*: uint32
  GDK_KEY_KP_Separator*: uint32
  GDK_KEY_KP_Subtract*: uint32
  GDK_KEY_KP_Decimal*: uint32
  GDK_KEY_KP_Divide*: uint32
  GDK_KEY_KP_0*: uint32
  GDK_KEY_KP_1*: uint32
  GDK_KEY_KP_2*: uint32
  GDK_KEY_KP_3*: uint32
  GDK_KEY_KP_4*: uint32
  GDK_KEY_KP_5*: uint32
  GDK_KEY_KP_6*: uint32
  GDK_KEY_KP_7*: uint32
  GDK_KEY_KP_8*: uint32
  GDK_KEY_KP_9*: uint32
  GDK_KEY_F1*: uint32
  GDK_KEY_F2*: uint32
  GDK_KEY_F3*: uint32
  GDK_KEY_F4*: uint32
  GDK_KEY_F5*: uint32
  GDK_KEY_F6*: uint32
  GDK_KEY_F7*: uint32
  GDK_KEY_F8*: uint32
  GDK_KEY_F9*: uint32
  GDK_KEY_F10*: uint32
  GDK_KEY_F11*: uint32
  GDK_KEY_F12*: uint32
  GDK_KEY_F13*: uint32
  GDK_KEY_F14*: uint32
  GDK_KEY_F15*: uint32
  GDK_KEY_F16*: uint32
  GDK_KEY_F17*: uint32
  GDK_KEY_F18*: uint32
  GDK_KEY_F19*: uint32
  GDK_KEY_F20*: uint32
  GDK_KEY_F21*: uint32
  GDK_KEY_F22*: uint32
  GDK_KEY_F23*: uint32
  GDK_KEY_F24*: uint32
  GDK_KEY_Shift_L*: uint32
  GDK_KEY_Shift_R*: uint32
  GDK_KEY_Control_L*: uint32
  GDK_KEY_Control_R*: uint32
  GDK_KEY_Caps_Lock*: uint32
  GDK_KEY_Shift_Lock*: uint32
  GDK_KEY_Meta_L*: uint32
  GDK_KEY_Meta_R*: uint32
  GDK_KEY_Alt_L*: uint32
  GDK_KEY_Alt_R*: uint32
  GDK_KEY_Super_L*: uint32
  GDK_KEY_Super_R*: uint32
  GDK_KEY_Hyper_L*: uint32
  GDK_KEY_Hyper_R*: uint32

proc gdk_keyval_to_unicode*(keyval: uint32): uint32

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
proc gtk_box_remove*(box: ptr EGtkWidget, child: ptr EGtkWidget)
proc gtk_window_set_child*(window: ptr EGtkWidget, child: ptr EGtkWidget)
proc gtk_window_set_default_size*(window: ptr EGtkWidget, width: int32, height: int32)
proc gtk_window_set_title*(window: ptr EGtkWidget, title: cstring)
proc gtk_window_present*(window: ptr EGtkWidget)

proc gtk_widget_get_width*(widget: ptr EGtkWidget): int32
proc gtk_widget_get_height*(widget: ptr EGtkWidget): int32
proc gtk_widget_set_hexpand*(widget: ptr EGtkWidget, expand: bool)
proc gtk_widget_set_vexpand*(widget: ptr EGtkWidget, expand: bool)
proc gtk_widget_set_halign*(widget: ptr EGtkWidget, align: int32)
proc gtk_widget_set_valign*(widget: ptr EGtkWidget, align: int32)
proc gtk_widget_add_css_class*(widget: ptr EGtkWidget, class: cstring)
proc gtk_widget_get_parent*(widget: ptr EGtkWidget): ptr EGtkWidget
proc gtk_widget_grab_focus*(widget: ptr EGtkWidget): int32
proc gtk_widget_set_focusable*(widget: ptr EGtkWidget, focusable: bool)

proc gtk_gesture_click_new*(): ptr EGtkWidget
proc gtk_gesture_single_set_button*(gesture: ptr EGtkWidget, btn: int32)

proc gtk_picture_set_can_shrink*(picture: ptr EGtkWidget, canShrink: bool)

proc gtk_picture_new*(): ptr EGtkWidget
proc gtk_picture_set_paintable*(picture: ptr EGtkWidget, paintable: pointer)

proc gtk_entry_new*(): ptr EGtkWidget
proc gtk_entry_set_placeholder_text*(entry: ptr EGtkWidget, text: cstring)
proc gtk_editable_get_text*(editable: ptr EGtkWidget): cstring

proc gtk_widget_set_size_request*(widget: ptr EGtkWidget, h, v: int32)
proc gtk_widget_set_cursor_from_name*(widget: ptr EGtkWidget, cursor: cstring)

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

proc gtk_image_new_from_icon_name*(name: cstring): ptr EGtkWidget
proc gtk_image_set_pixel_size*(widget: ptr EGtkWidget, size: int32)

proc gtk_label_new*(text: cstring): ptr EGtkWidget

proc gtk_event_controller_scroll_new*(axes: int32): ptr EGtkWidget
proc gtk_event_controller_motion_new*(): ptr EGtkWidget

proc gtk_event_controller_key_new*(): ptr EGtkWidget

proc gtk_widget_add_controller*(widget: ptr EGtkWidget, controller: ptr EGtkWidget)

proc g_application_run*(app: ptr AdwApplication, argc: int32, argv: ptr cstring): int32
proc g_object_unref*(obj: pointer)

proc adw_alert_dialog_new*(heading, body: cstring): ptr EGtkWidget
proc adw_alert_dialog_add_response*(dialog: ptr EGtkWidget, id, label: cstring)
proc adw_alert_dialog_set_default_response*(dialog: ptr EGtkWidget, id: cstring)
proc adw_alert_dialog_set_close_response*(dialog: ptr EGtkWidget, id: cstring)
proc adw_dialog_present*(dialog: ptr EGtkWidget, window: ptr EGtkWidget)

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
