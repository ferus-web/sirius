/* Super evil core script.
 * Used by WebView to schedule tasks on this runtime's macrotask queue,
 * so that it can accurately time things.
 *
 * Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
*/

function handleRefreshMeta(time, url) {
  // This just exists as a convenience wrapper for WebView to handle a
  // <meta http-equiv="refresh"> element.
  
  setTimeout(function() {
    loadURL(url);
  }, time * 1000) // NOTE: Time comes in as seconds.
}
