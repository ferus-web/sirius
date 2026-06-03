# Minimal libcurl bindings used by `components::net`.

{.passC: "-DCURL_DISABLE_TYPECHECK".}

type
  CURL* = ptr object
  CURLM* = ptr object
  CURLU* = ptr object
  CURLcode* = distinct int32
  CURLUCode* = distinct int32
  CURLMcode* = distinct int32
  CURLoption* = distinct int32
  CURLMoption* = distinct int32
  CURLINFO* = distinct int32

  CURLUPart* {.pure, importc, size: sizeof(uint8).} = enum
    URL
    Scheme
    User
    Password
    Options
    Host
    Port
    Path
    Query
    Fragment
    ZoneID

  curl_slist* {.
    importc: "struct curl_slist", header: "<curl/curl.h>", incompleteStruct
  .} = object

  CURLMsgData* {.union.} = object
    whatever*: pointer
    result*: CURLcode

  CurlMsgType* = distinct cint

  CURLMsg* {.importc: "CURLMsg", header: "<curl/multi.h>", bycopy.} = object
    msg*: CurlMsgType
    easy_handle*: CURL
    data*: CURLMsgData

  curl_write_callback* =
    proc(buffer: ptr char, size, nitems: csize_t, outstream: pointer): csize_t {.cdecl.}

proc `==`*(a, b: CURLcode): bool {.borrow.}
proc `==`*(a, b: CURLUCode): bool {.borrow.}
proc `==`*(a, b: CURLMcode): bool {.borrow.}
proc `==`*(a, b: CurlMsgType): bool {.borrow.}

const
  CURLE_OK* = CURLcode(0)
  CURLE_COULDNT_RESOLVE_PROXY* = CURLcode(5)
  CURLE_COULDNT_RESOLVE_HOST* = CURLcode(6)
  CURLE_COULDNT_CONNECT* = CURLcode(7)
  CURLE_OPERATION_TIMEDOUT* = CURLcode(28)
  CURLE_SSL_CONNECT_ERROR* = CURLcode(35)
  CURLE_ABORTED_BY_CALLBACK* = CURLcode(42)
  CURLE_PEER_FAILED_VERIFICATION* = CURLcode(60)

  CURLM_OK* = CURLMcode(0)

  CURLOPTTYPE_LONG* = 0
  CURLOPTTYPE_OBJECTPOINT* = 10000
  CURLOPTTYPE_FUNCTIONPOINT* = 20000

  CURLOPT_WRITEDATA* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 1)
  CURLOPT_URL* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 2)
  CURLOPT_ERRORBUFFER* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 10)
  CURLOPT_WRITEFUNCTION* = CURLoption(CURLOPTTYPE_FUNCTIONPOINT + 11)
  CURLOPT_POSTFIELDS* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 15)
  CURLOPT_USERAGENT* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 18)
  CURLOPT_HTTPHEADER* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 23)
  CURLOPT_HEADERDATA* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 29)
  CURLOPT_CUSTOMREQUEST* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 36)
  CURLOPT_NOBODY* = CURLoption(CURLOPTTYPE_LONG + 44)
  CURLOPT_POST* = CURLoption(CURLOPTTYPE_LONG + 47)
  CURLOPT_FOLLOWLOCATION* = CURLoption(CURLOPTTYPE_LONG + 52)
  CURLOPT_POSTFIELDSIZE* = CURLoption(CURLOPTTYPE_LONG + 60)
  CURLOPT_SSL_VERIFYPEER* = CURLoption(CURLOPTTYPE_LONG + 64)
  CURLOPT_MAXREDIRS* = CURLoption(CURLOPTTYPE_LONG + 68)
  CURLOPT_HEADERFUNCTION* = CURLoption(CURLOPTTYPE_FUNCTIONPOINT + 79)
  CURLOPT_SSL_VERIFYHOST* = CURLoption(CURLOPTTYPE_LONG + 81)
  CURLOPT_HTTP_VERSION* = CURLoption(CURLOPTTYPE_LONG + 84)
  CURLOPT_NOSIGNAL* = CURLoption(CURLOPTTYPE_LONG + 99)
  CURLOPT_ACCEPT_ENCODING* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 102)
  CURLOPT_TIMEOUT_MS* = CURLoption(CURLOPTTYPE_LONG + 155)
  CURLOPT_CONNECTTIMEOUT_MS* = CURLoption(CURLOPTTYPE_LONG + 156)
  CURLOPT_CURLU* = CURLoption(CURLOPTTYPE_OBJECTPOINT + 282)

  CURL_HTTP_VERSION_2TLS* = clong(4)

  CURLMOPT_PIPELINING* = CURLMoption(CURLOPTTYPE_LONG + 3)

  CURLPIPE_MULTIPLEX* = clong(2)

  CURLMSG_NONE* = CurlMsgType(0)
  CURLMSG_DONE* = CurlMsgType(1)
  CURLMSG_LAST* = CurlMsgType(2)

  CURLINFO_LONG* = 0x200000
  CURLINFO_STRING* = 0x100000
  CURLINFO_EFFECTIVE_URL* = CURLINFO(CURLINFO_STRING + 1)
  CURLINFO_RESPONSE_CODE* = CURLINFO(CURLINFO_LONG + 2)

  CURLUE_OK* = CURLUCode(0)
  CURLUE_BAD_HANDLE* = CURLUCode(1)
  CURLUE_BAD_PARTPOINTER* = CURLUCode(2)
  CURLUE_MALFORMED_INPUT* = CURLUCode(3)
  CURLUE_BAD_PORT_NUMBER* = CURLUCode(4)
  CURLUE_UNSUPPORTED_SCHEME* = CURLUCode(5)
  CURLUE_URLDECODE* = CURLUCode(6)
  CURLUE_OUT_OF_MEMORY* = CURLUCode(7)
  CURLUE_USER_NOT_ALLOWED* = CURLUCode(8)
  CURLUE_UNKNOWN_PART* = CURLUCode(9)
  CURLUE_NO_SCHEME* = CURLUCode(10)
  CURLUE_NO_USER* = CURLUCode(11)
  CURLUE_NO_PASSWORD* = CURLUCode(12)
  CURLUE_NO_OPTIONS* = CURLUCode(13)
  CURLUE_NO_HOST* = CURLUCode(14)
  CURLUE_NO_PORT* = CURLUCode(15)
  CURLUE_NO_QUERY* = CURLUCode(16)
  CURLUE_NO_FRAGMENT* = CURLUCode(17)
  CURLUE_NO_ZONEID* = CURLUCode(18)
  CURLUE_BAD_FILE_URL* = CURLUCode(19)
  CURLUE_BAD_FRAGMENT* = CURLUCode(20)
  CURLUE_BAD_HOSTNAME* = CURLUCode(21)
  CURLUE_BAD_IPV6* = CURLUCode(22)
  CURLUE_BAD_LOGIN* = CURLUCode(23)
  CURLUE_BAD_PASSWORD* = CURLUCode(24)
  CURLUE_BAD_PATH* = CURLUCode(25)
  CURLUE_BAD_QUERY* = CURLUCode(26)
  CURLUE_BAD_SCHEME* = CURLUCode(27)
  CURLUE_BAD_SLASHES* = CURLUCode(28)
  CURLUE_BAD_USER* = CURLUCode(29)
  CURLUE_LACKS_IDN* = CURLUCode(30)
  CURLUE_TOO_LARGE* = CURLUCode(31)

{.push importc, callconv: cdecl, header: "<curl/curl.h>".}

proc curl_easy_init*(): CURL
proc curl_easy_cleanup*(curl: CURL)
proc curl_easy_reset*(curl: CURL)
proc curl_easy_setopt*(curl: CURL, option: CURLoption): CURLcode {.varargs.}
proc curl_easy_setopt_url*(curl: CURL, option: CURLoption, u: CURLU): CURLcode
proc curl_easy_getinfo*(curl: CURL, info: CURLINFO): CURLcode {.varargs.}
proc curl_easy_strerror*(code: CURLcode): cstring

proc curl_slist_append*(list: ptr curl_slist, data: cstring): ptr curl_slist
proc curl_slist_free_all*(list: ptr curl_slist)

proc curl_global_init*(flags: culong): CURLcode
proc curl_global_cleanup*()

{.pop.}

{.push importc, callconv: cdecl, header: "<curl/multi.h>".}

proc curl_multi_init*(): CURLM
proc curl_multi_setopt*(multiHandle: CURLM, option: CURLMoption): CURLMcode {.varargs.}
proc curl_multi_add_handle*(multiHandle: CURLM, easyHandle: CURL): CURLMcode
proc curl_multi_remove_handle*(multiHandle: CURLM, easyHandle: CURL): CURLMcode
proc curl_multi_perform*(multiHandle: CURLM, runningHandles: ptr cint): CURLMcode
proc curl_multi_poll*(
  multiHandle: CURLM,
  extraFds: pointer,
  extraNfds: cuint,
  timeoutMs: cint,
  numfds: ptr cint,
): CURLMcode

proc curl_multi_info_read*(multiHandle: CURLM, msgsInQueue: ptr cint): ptr CURLMsg
proc curl_multi_cleanup*(multiHandle: CURLM): CURLMcode
proc curl_multi_strerror*(code: CURLMcode): cstring

{.pop.}

{.push importc, callconv: cdecl, header: "<curl/urlapi.h>".}

proc curl_url*(): CURLU
proc curl_url_cleanup*(u: CURLU)
proc curl_url_dup*(u: CURLU): CURLU
proc curl_url_set*(
  u: CURLU, what: CURLUPart, part: cstring | ptr char, flags: int32
): CURLUCode

proc curl_url_strerror*(err: CURLUCode): cstring

{.pop.}
