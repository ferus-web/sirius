import std/[options]
import
  ../../webview/[core, types],
  ../../embedding/prelude,
  ../../../components/synapse/[decoder, types],
  ../../../components/synapse/descriptors/master,
  ../../../components/aux/pretty
import pkg/[shakar, url, vmath]

let view =
  initWebView(WebViewOpts(embedding: EmbeddingOpts(namespace: "hello", enabled: true)))

view.onFrameDrawn = proc(view: WebView, _: TabID) =
  debugEcho "frame drawn"

view.onReconstruct = proc(view: WebView, _: TabID) =
  debugEcho "reconstruct framebuffer"

view.onResize = proc(view: WebView, _: TabID, size: vmath.IVec2) =
  debugEcho "resize: " & $size

view.onProcessFault = proc(view: WebView, _: TabID, process: Process) =
  debugEcho "process crashed: " & $process.kind

view.onAlert = proc(view: WebView, _: TabID, msg: Option[string]) =
  debugEcho "alert: " & $msg

view.onClipboardWriteText = proc(
    view: WebView, _: TabID, text: string, promiseId: uint32
) =
  debugEcho "clipboard write text"
  debugEcho "text: " & text
  debugEcho "promise ID: " & $promiseId

view.bindFn(
  "nativePrint",
  proc(view: WebView, msg: Message[MasterOp]) =
    echo "nativePrint called in master!!!"
    let msg = &msg.argument(1, string)
    echo "JS says: " & msg
  ,
)

let tab = view.createTab()

view.loadURL(tab, parseURL("file://src/examples/hello/index.html"))

while true:
  view.step()
