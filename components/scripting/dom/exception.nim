## `DOMException` implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import
  components/dom/dom,
  components/js/runtime/prelude,
  components/js/stdlib/[errors, errors_ir]
import pkg/[chronicles, shakar]

logScope:
  topics = "dom/exception"

type DOMException* = object of Error

const CodeField = "code"

proc codeGetter(rt: Runtime, this: JSValue): JSValue =
  &this.getHiddenField(CodeField)

proc throwDomException*(rt: Runtime, code: DOMExceptionCode, message: string) =
  let err = rt.createObjFromType(DOMException)
  err.setHiddenField(CodeField, rt.wrap(cast[uint16](code)))

  rt.throw(DOMException, err = err, message = message)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("DOMException", DOMException)
  runtime.setProperty(DOMException, "INDEX_SIZE_ERR", DOMExceptionCode.IndexSize)
  runtime.setProperty(
    DOMException, "DOMSTRING_SIZE_ERR", DOMExceptionCode.DomstringSize
  )
  runtime.setProperty(
    DOMException, "HIERARCHY_REQUEST_ERR", DOMExceptionCode.HierarchyRequest
  )
  runtime.setProperty(
    DOMException, "WRONG_DOCUMENT_ERR", DOMExceptionCode.WrongDocument
  )
  runtime.setProperty(
    DOMException, "INVALID_CHARACTER_ERR", DOMExceptionCode.InvalidCharacter
  )
  runtime.setProperty(
    DOMException, "NO_DATA_ALLOWED_ERR", DOMExceptionCode.NoDataAllowed
  )
  runtime.setProperty(
    DOMException, "NO_MODIFICATION_ALLOWED_ERR", DOMExceptionCode.NoModificationAllowed
  )
  runtime.setProperty(DOMException, "NOT_FOUND_ERR", DOMExceptionCode.NotFound)
  runtime.setProperty(DOMException, "NOT_SUPPORTED_ERR", DOMExceptionCode.NotSupported)
  runtime.setProperty(
    DOMException, "INUSE_ATTRIBUTE_ERR", DOMExceptionCode.InuseAttribute
  )
  runtime.setProperty(DOMException, "INVALID_STATE_ERR", DOMExceptionCode.InvalidState)
  runtime.setProperty(DOMException, "SYNTAX_ERR", DOMExceptionCode.Syntax)
  runtime.setProperty(
    DOMException, "INVALID_MODIFICATION_ERR", DOMExceptionCode.InvalidModification
  )
  runtime.setProperty(DOMException, "NAMESPACE_ERR", DOMExceptionCode.Namespace)
  runtime.setProperty(
    DOMException, "INVALID_ACCESS_ERR", DOMExceptionCode.InvalidAccess
  )
  runtime.setProperty(DOMException, "VALIDATION_ERR", DOMExceptionCode.Validation)
  runtime.setProperty(DOMException, "TYPE_MISMATCH_ERR", DOMExceptionCode.TypeMismatch)
  runtime.setProperty(DOMException, "SECURITY_ERR", DOMExceptionCode.Security)
  runtime.setProperty(DOMException, "NETWORK_ERR", DOMExceptionCode.Network)
  runtime.setProperty(DOMException, "ABORT_ERR", DOMExceptionCode.Abort)
  runtime.setProperty(DOMException, "URL_MISMATCH_ERR", DOMExceptionCode.UrlMismatch)
  runtime.setProperty(
    DOMException, "QUOTA_EXCEEDED_ERR", DOMExceptionCode.QuotaExceeded
  )
  runtime.setProperty(DOMException, "TIMEOUT_ERR", DOMExceptionCode.Timeout)
  runtime.setProperty(
    DOMException, "INVALID_NODE_TYPE_ERR", DOMExceptionCode.InvalidNodeType
  )
  runtime.setProperty(DOMException, "DATA_CLONE_ERR", DOMExceptionCode.DataClone)
  runtime.defineAccessor(
    DOMException,
    "code",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret codeGetter(rt = runtime, this = this)
    ),
  )
