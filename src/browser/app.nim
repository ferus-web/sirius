## GTK4 browser shell implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/owlkettle, pkg/owlkettle/adw
import ../webview/[core, types]

viewable Browser:
  view:
    WebView

method view(browser: BrowserState): Widget =
  result = gui:
    AdwWindow:
      iconName = "sirius"
      defaultSize = (640, 480)

      Box:
        orient = OrientY

        AdwHeaderBar {.expand: false.}:
          WindowTitle {.addTitle.}:
            title = "Sirius"

proc startBrowserShell*(view: WebView) =
  adw.brew(gui(Browser(view = view)))
