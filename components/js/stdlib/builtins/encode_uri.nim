## Implementation of encodeURI()
## Author(s):
## Trayambak Rai (xtrayambak at disroot dot org)
import components/js/runtime/[arguments, bridge, types, construction]
import components/js/runtime/abstract/coercion
import components/js/internal/[uri_coding]
import pkg/shakar

proc generateStdIR*(runtime: Runtime) =
  runtime.defineFn(
    "encodeURI",
    proc() =
      let uri =
        if runtime.argumentCount() > 0:
          &runtime.argument(1)
        else:
          undefined(runtime)

      # 1. Let uriString be ? ToString(uri)
      let uriString = runtime.ToString(uri)

      # 2. Let extraUnescaped be ";/?:@&=+$,#"
      const extraUnescaped: set[char] =
        {';', '/', '?', ':', '@', '&', '=', '+', '$', ',', '#'}

      # 3. Return ? Encode (uriString, extraUnescaped)
      ret encode(uriString, extraUnescaped)
    ,
  )
