/* Super evil core script.
 * Used by WebView to schedule tasks on this runtime's macrotask queue,
 * so that it can accurately time things.
 *
 * Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
*/

// NOTE: Also note that the engine only calls setTimeout() tasks here once,
// that is *very* much intentional design. This behaviour is not seen in
// regular scripts for obvious semantic correctness reasons.

function handleRefreshMeta(time, url) {
  // This just exists as a convenience wrapper for WebView to handle a
  // <meta http-equiv="refresh"> element.
  
  setTimeout(function() {
    loadURL(url);
  }, time * 1000) // NOTE: Time comes in as seconds.
}
