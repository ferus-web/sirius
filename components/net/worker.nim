import components/net/types, components/os/threads
import pkg/[chronicles, curly, url]

logScope:
  topics = "net/worker"

proc networkWorker(net: NetworkClient) {.thread.} =
  debug "Entering main loop"
  setThreadName("Network")

  while true:
    let (response, error) = curl.waitForResponse()
    if error.len > 0:
      discard
