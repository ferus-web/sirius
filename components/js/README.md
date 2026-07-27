# Bali
This directory contains all the code for the JavaScript engine, Bali. It is a hard-fork of [the Bali JS engine](https://github.com/ferus-web/bali) from earlier.

It contains various improvements and refactors over its original implementation:
- Hidden/internal fields in objects
- Better edge case handling in methods like `ToString()`
- Better tracebacks
- Much more compliance work (functions-as-arguments, codegen bugs, etc.)
- Optimization work mostly revolving around reducing memory usage

**NOTE**: If you're looking for the web host bindings, you won't find them here. They live at [components/scripting](https://git.xtrayambak.xyz/ferus-web/sirius/src/branch/master/components/scripting). This component is simply an implementation of ECMAScript, as well as a FFI layer.

## balde
The engine runner CLI is still called Balde, and mostly has the same flags.
