## Small wrapper over ICU's `TimeZone` class
## Author: Trayambak Rai (xtrayambak at disroot dot org)
#[ import pkg/icu4nim

when defined(baliStaticallyLinkLibICU):
  {.passC: "-static".} ]#

# TODO: Should we link in ICU? It's a massive library and it'll require us to switch to the C++ backend...
proc getCurrentTimeZone*(): string {.gcsafe.} =
  #[ var status = ZeroError

  var tz = detectHostTimeZone()
  if tz == nil:
    warn "getCurrentTimeZone: `icu::TimeZone::detectHostTimeZone()` returned NULL!"
    warn "getCurrentTimeZone: returning \"UTC\" as timezone."
    return "UTC"

  var timeZoneId: UnicodeString
  tz.getID(timeZoneId)
  debug "getCurrentTimeZone: timeZoneId = " & $timeZoneId

  var timeZoneName: UnicodeString
  tz.getCanonicalID(timeZoneId, timeZoneName, status)
  debug "getCurrentTimeZone: timeZoneName = " & $timeZoneName

  if status != ZeroError:
    warn "getCurrentTimeZone: ICU returned error code: " & $status
    warn "getCurrentTimeZone: returning \"UTC\" as timezone."
    return "UTC" ]#

  "UTC"

#[ proc clearSystemTimeZoneCache*() {.sideEffect.} =
  debug "timezone: cleared system timezone cache"
  cachedSystemTimeZone.reset() ]#
