## Sirius' embedding API and its routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[importutils, tables]
import
  ../webview/types,
  ../../components/synapse/[decoder, encoder, types, master],
  ../../components/synapse/descriptors/[master, renderer],
  ../../components/synapse/transport/socketpairs,
  ../../components/scripting/embedding
import pkg/[results, shakar, url]

export master.MasterOp, embedding.EmbeddingOpts, types, decoder.argument

proc bindFn*(view: WebView, name: string, fn: EmbeddedFunctionCallback) =
  privateAccess(WebView)

  view.routedFns[name] = fn

proc insertScript*(
    view: WebView, tab: uint32, baseURL: url.URL, code: string
): Result[void, string] {.discardable.} =
  let process = &view.master.tabs[tab].renderer()

  view.master.encoder.encode(RenderOp.InsertScript)
  view.master.encoder.push(baseURL)
  view.master.encoder.push(code)
  view.master.send(process.trig.fd)
