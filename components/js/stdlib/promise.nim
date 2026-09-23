## Implementation of `Promise`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, options]
import
  components/js/runtime/[arguments, atom_helpers, bridge, construction, types, wrapping],
  components/js/runtime/abstract/[callables, equating],
  components/js/stdlib/[errors_common, errors],
  components/js/runtime/vm/atom,
  components/js/runtime/vm/heap/manager
import pkg/shakar

type
  PromiseReactionJob* = object
    job*: JSValue
    handlerRealm*: Realm

  PromiseOrEmptyRecord* = object
    value*: Option[JSValue]

  ResolvingFunctionsRecord* = object
    resolve*, reject*: JSValue

  PromiseState* {.pure, size: sizeof(uint8).} = enum
    ## Governs how a promise will react to incoming calls to its then method. 
    Pending = 0
    Fulfilled
    Rejected

  PromiseCapability* = object
    ## https://tc39.es/ecma262/#sec-promisecapability-records
    ## A PromiseCapability Record is a Record used to encapsulate a Promise or promise-like object along with the functions that are capable of resolving or rejecting that promise.
    ## PromiseCapability Records are produced by the NewPromiseCapability abstract operation.
    promise*: Promise
    resolve*, reject*: JSValue

  JobCallback* = object
    ## https://tc39.es/ecma262/#sec-jobcallback-records
    ## A JobCallback Record is a Record used to store a function object and a host-defined value. Function objects that are invoked via a Job enqueued by the host may have additional host-defined context.
    ## To propagate the state, Job Abstract Closures should not capture and call function objects directly. Instead, use HostMakeJobCallback and HostCallJobCallback.
    callback*: JSValue
    hostDefined*: Option[JSValue]

  PromiseReactionKind* {.pure, size: sizeof(uint8).} = enum
    Fulfill = 0
    Reject

  PromiseReactionObj = object
    ## https://tc39.es/ecma262/#sec-promisereaction-records
    ## A PromiseReaction Record is a Record used to store information about how a promise should react when it becomes resolved or rejected with a given value.
    ## PromiseReaction Records are created by the PerformPromiseThen abstract operation, and are used by the Abstract Closure returned by NewPromiseReactionJob.
    capability*: Option[PromiseCapability]
    kind*: PromiseReactionKind
    handler*: Option[JobCallback]

  PromiseReaction* = ptr PromiseReactionObj

  PromiseObj = object
    ## https://tc39.es/ecma262/#sec-promise-objects
    ## Promise instances are ordinary objects that inherit properties from the Promise prototype object (the intrinsic, %Promise.prototype%).
    ## Promise instances are initially created with the internal slots described in Table 93.
    ## This is the internal implementation that native code uses.
    state*: PromiseState
    res*: Option[JSValue]
    fulfillReactions*, rejectReactions*: JSValue
    isHandled*: bool

  Promise = ptr PromiseObj
  JSPromise = object

func HostJobMakeCallback*(callback: JSValue): JobCallback {.raises: [].} =
  ## https://tc39.es/ecma262/#sec-hostmakejobcallback
  ## The host-defined abstract operation HostMakeJobCallback takes argument callback (a function object) and returns a JobCallback Record.

  ## The default implementation of HostMakeJobCallback performs the following steps when called:

  # 1. Return the JobCallback Record { [[Callback]]: callback, [[HostDefined]]: empty }.
  JobCallback(callback: callback, hostDefined: none(JSValue))

func HostEnqueueGenericJob*(rt: Runtime, job: Microtask) =
  ## https://tc39.es/ecma262/#sec-hostenqueuegenericjob
  ## The host-defined abstract operation HostEnqueueGenericJob takes arguments job (a Job Abstract Closure) and realm (a Realm Record) and returns unused.
  ## It schedules job in the realm realm in the agent signified by realm.[[AgentSignifier]] to be performed at some future time. The Abstract Closures used with this algorithm are intended to be scheduled without additional constraints, such as priority and ordering.
  rt.microtaskQueue.addLast(job)

proc HostCallJobCallback*(
    rt: Runtime, jobCallback: JobCallback, thisValue: JSValue, argList: seq[JSValue]
): JSValue =
  ## https://tc39.es/ecma262/#sec-hostcalljobcallback
  ## The host-defined abstract operation HostCallJobCallback takes arguments jobCallback (a JobCallback Record), thisValue (an ECMAScript language value), and argList (a List of ECMAScript language values) and returns either a normal completion containing an ECMAScript language value or a throw completion.

  # 1. Assert: IsCallable(jobCallback.[[Callback]]) is true.
  assert(IsCallable(rt, jobCallback.callback))

  # 2. Return ? Call(jobCallback.[[Callback]], thisValue, argList).
  rt.call(jobCallback.callback, this = thisValue, arguments = argList)

proc NewPromiseReactionJob*(
    rt: Runtime, reactionObj: JSValue, arg: JSValue
): PromiseReactionJob =
  ## https://tc39.es/ecma262/#sec-newpromisereactionjob
  ## The abstract operation NewPromiseReactionJob takes arguments reaction (a PromiseReaction Record) and arg (an ECMAScript language value) and returns a Record with fields [[Job]] (a Job Abstract Closure) and [[Realm]] (a Realm Record or null).
  ## It returns a new Job Abstract Closure that applies the appropriate handler to the incoming value, and uses the handler's return value to resolve or reject the derived promise associated with that handler.

  # 1. Let job be a new Job Abstract Closure with no parameters that captures reaction and arg and performs the following steps when called:
  let reaction = &reactionObj.getPrivateObject(PromiseReaction)
  let job = nativeCallable(
    rt,
    proc() =
      let
        runtime = rt # HACK: This is a code smell
        promiseCapability = reaction.capability
          # a. Let promiseCapability be reaction.[[Capability]].
        typ = reaction.kind # b. Let type be reaction.[[Type]].
        handler = reaction.handler # c. Let handler be reaction.[[Handler]].

      var
        isThrow = false # TODO: Get Completions working someday :P
        handlerResult: JSValue

      # d. If handler is empty, then
      if !handler:
        # i. If type is fulfill, then
        if typ == PromiseReactionKind.Fulfill:
          # 1. Let handlerResult be NormalCompletion(arg).
          handlerResult = arg
          isThrow = false
        else:
          # ii. Else,
          # 1. Assert: type is reject.
          assert(typ == PromiseReactionKind.Reject)

          # 2. Let handlerResult be ThrowCompletion(arg).
          handlerResult = arg
          isThrow = true
      else:
        # e. Else,
        # i. Let handlerResult be Completion(HostCallJobCallback(handler, undefined, « arg »)).
        handlerResult = HostCallJobCallback(rt, &handler, undefined(rt), @[arg])
        isThrow = false

      # f. If promiseCapability is undefined, then
      if !promiseCapability:
        # i. Assert: handlerResult is not an abrupt completion.
        assert(not isThrow)

        # ii. Return empty.
        ret undefined(rt)

      # g. Assert: promiseCapability is a PromiseCapability Record.
      let capability = &promiseCapability

      # h. If handlerResult is an abrupt completion, then
      if isThrow:
        # i. Return ? Call(promiseCapability.[[Reject]], undefined, « handlerResult.[[Value]] »).
        ret rt.call(capability.reject, this = undefined(rt), @[handlerResult])

      # i. Return ? Call(promiseCapability.[[Resolve]], undefined, « handlerResult.[[Value]] »).
      ret rt.call(capability.resolve, this = undefined(rt), @[handlerResult])
    ,
  )

  # 2. Let handlerRealm be null.
  # 3. If reaction.[[Handler]] is not empty, then
  # TODO: Implement the realm fetching stuff

  # 4. Return the Record { [[Job]]: job, [[Realm]]: handlerRealm }.
  PromiseReactionJob(job: job)

proc HostEnqueuePromiseJob*(rt: Runtime, job: PromiseReactionJob) =
  ## https://tc39.es/ecma262/#sec-hostenqueuepromisejob

  # TODO: I'm not too sure if this is fully conforming.
  rt.microtaskQueue.addLast(job.job)

proc TriggerPromiseReactions*(rt: Runtime, reactions: JSValue, arg: JSValue) =
  ## https://tc39.es/ecma262/#sec-triggerpromisereactions
  ## The abstract operation TriggerPromiseReactions takes arguments reactions (a List of PromiseReaction Records) and arg (an ECMAScript language value) and returns unused.
  ## It enqueues a new Job for each record in reactions.
  ## Each such Job processes the [[Type]] and [[Handler]] of the PromiseReaction Record, and if the [[Handler]] is not empty, calls it passing the given argument.
  ## If the [[Handler]] is empty, the behaviour is determined by the [[Type]].
  assert(reactions.kind == Sequence)

  # 1. For each element reaction of reactions, do
  for reaction in reactions.sequence:
    # a. Let job be NewPromiseReactionJob(reaction, arg).
    let job = NewPromiseReactionJob(rt, reaction, arg)

    # b. Perform HostEnqueuePromiseJob(job.[[Job]], job.[[Realm]]).
    HostEnqueuePromiseJob(rt, job)

  # 2. Return unused.

proc RejectPromise*(rt: Runtime, promiseObj: JSValue, reason: JSValue) =
  ## https://tc39.es/ecma262/#sec-rejectpromise
  ## The abstract operation RejectPromise takes arguments promise (a Promise) and reason (an ECMAScript language value) and returns unused.

  let promise = &promiseObj.getPrivateObject(Promise)

  # 1. Assert: promise.[[PromiseState]] is pending.
  assert(promise.state == PromiseState.Pending)

  # 2. Let reactions be promise.[[PromiseRejectReactions]].
  let reactions = promise.rejectReactions

  # 3. Set promise.[[PromiseResult]] to reason.
  promise.res = some(reason)

  # 4. Set promise.[[PromiseFulfillReactions]] to undefined.
  promise.fulfillReactions = undefined(rt)

  # 5. Set promise.[[PromiseRejectReactions]] to undefined.
  promise.rejectReactions = undefined(rt)

  # 6. Set promise.[[PromiseState]] to rejected.
  promise.state = PromiseState.Rejected

  # 7. If promise.[[PromiseIsHandled]] is false, perform HostPromiseRejectionTracker(promise, "reject").
  if not promise.isHandled:
    discard
      "TODO: HostPromiseRejectionTracker (maybe it could be a fn in Runtime. I should probably make a vtable in there for stuff, or multiple ones.)"

  # 8. Perform TriggerPromiseReactions(reactions, reason).
  TriggerPromiseReactions(rt, reactions, reason)

  # 9. Return unused.

proc FulfillPromise*(rt: Runtime, promiseObj: JSValue, value: JSValue) =
  ## https://tc39.es/ecma262/#sec-fulfillpromise
  ## The abstract operation FulfillPromise takes arguments promise (a Promise) and value (an ECMAScript language value) and returns unused.

  let promise = &promiseObj.getPrivateObject(Promise)

  # 1. Assert: promise.[[PromiseState]] is pending.
  assert(promise.state == PromiseState.Pending)

  # 2. Let reactions be promise.[[PromiseFulfillReactions]].
  let reactions = promise.fulfillReactions

  # 3. Set promise.[[PromiseResult]] to value.
  promise.res = some(value)

  # 4. Set promise.[[PromiseFulfillReactions]] to undefined.
  promise.fulfillReactions = undefined(rt)

  # 5. Set promise.[[PromiseRejectReactions]] to undefined.
  promise.rejectReactions = undefined(rt)

  # 6. Set promise.[[PromiseState]] to fulfilled.
  promise.state = PromiseState.Fulfilled

  # 7. Perform TriggerPromiseReactions(reactions, value).
  TriggerPromiseReactions(rt, reactions, value)

  # 8. Return unused.

proc CreateResolvingFunctions*(
    runtime: Runtime, toResolve: JSValue
): ResolvingFunctionsRecord =
  ## https://tc39.es/ecma262/#sec-createresolvingfunctions
  ## The abstract operation CreateResolvingFunctions takes argument toResolve (a Promise) and returns a Record with fields [[Resolve]] (a function object) and [[Reject]] (a function object).

  # 1. Let promiseOrEmpty be the Record { [[Value]]: toResolve }.
  let promiseOrEmpty = runtime.realm.heap.allocate(PromiseOrEmptyRecord)
  promiseOrEmpty.value = some(toResolve)

  # 2. Let resolveSteps be a new Abstract Closure with parameters (resolution) that captures promiseOrEmpty and performs the following steps when called:
  let resolveSteps = nativeCallable(
    runtime,
    proc() =
      let resolution = &runtime.argument(1)

      # a. If promiseOrEmpty.[[Value]] is empty, return undefined.
      if !promiseOrEmpty.value:
        ret undefined(runtime)

      # b. Let promise be promiseOrEmpty.[[Value]].
      let promise = &promiseOrEmpty.value

      # c. Set promiseOrEmpty.[[Value]] to empty.
      promiseOrEmpty.value = none(JSValue)

      # d. If SameValue(resolution, promise) is true, then
      if sameValue(runtime, resolution, promise):
        # i. Let selfResolutionError be a newly created TypeError object.
        # ii. Perform RejectPromise(promise, selfResolutionError).

        # TODO: Proper TypeError implementation
        RejectPromise(runtime, promise, reason = undefined(runtime))

        # iii. Return undefined.
        ret undefined(runtime)

      # e. If resolution is not an Object, then
      if not resolution.isObject:
        # i. Perform FulfillPromise(promise, resolution).
        FulfillPromise(runtime, promise, resolution)

        # ii. Return undefined.
        ret undefined(runtime)

      # f. Let then be Completion(Get(resolution, "then")).
      let then = runtime.getProperty(resolution, "then")

      # g. If then is an abrupt completion, then
      if false:
        # TODO: Branch [g]
        # i. Perform RejectPromise(promise, then.[[Value]]).
        # ii. Return undefined.
        discard

      # h. Let thenAction be then.[[Value]].
      let thenAction = then

      # i. If IsCallable(thenAction) is false, then
      if not IsCallable(runtime, thenAction):
        # i. Perform FulfillPromise(promise, resolution).
        FulfillPromise(runtime, promise, resolution)

        # ii. Return undefined.
        ret undefined(runtime)

      # TODO: Implement the remaining steps [j - m]
      unreachable,
  )

  # 3. Let resolve be CreateBuiltinFunction(resolveSteps, 1, "", « »).
  let resolve = resolveSteps

  # 4. Let rejectSteps be a new Abstract Closure with parameters (reason) that captures promiseOrEmpty and performs the following steps when called:
  let rejectSteps = nativeCallable(
    runtime,
    proc() =
      let reason = &runtime.argument(1)

      # a. If promiseOrEmpty.[[Value]] is empty, return undefined.
      if !promiseOrEmpty.value:
        ret undefined(runtime)

      # b. Let promise be promiseOrEmpty.[[Value]].
      let promise = &promiseOrEmpty.value

      # c. Set promiseOrEmpty.[[Value]] to empty.
      promiseOrEmpty.value = none(JSValue)

      # d. Perform RejectPromise(promise, reason).
      RejectPromise(runtime, promise, reason)

      # e. Return undefined.
      ret undefined(runtime)
    ,
  )

  # 5. Let reject be CreateBuiltinFunction(rejectSteps, 1, "", « »).
  let reject = rejectSteps

  # 6. Return the Record { [[Resolve]]: resolve, [[Reject]]: reject }.
  ResolvingFunctionsRecord(resolve: resolve, reject: reject)

proc toJSPromise*(rt: Runtime, promise: Promise): JSValue =
  let obj = rt.createObjFromType(JSPromise)
  obj.setHiddenField("internal", rt.wrap(hidden(promise)))

  obj

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Promise", JSPromise)
  runtime.defineConstructor(
    "Promise",
    proc() =
      ## https://tc39.es/ecma262/#sec-promise-executor

      # This function performs the following steps when called:
      # TODO: 1. If NewTarget is undefined, throw a TypeError exception.

      let executor = &runtime.argument(1)

      # 2. If IsCallable(executor) is false, throw a TypeError exception.
      if not IsCallable(runtime, executor):
        runtime.typeError("Promise constructor expects first argument to be a callable")
        return

      # 3. Let promise be ? OrdinaryCreateFromConstructor(NewTarget, "%Promise.prototype%", « [[PromiseState]], [[PromiseResult]], [[PromiseFulfillReactions]], [[PromiseRejectReactions]], [[PromiseIsHandled]] »).
      let
        promiseObj = runtime.createObjFromType(JSPromise)
        promise = runtime.realm.heap.allocate(PromiseObj)

      promiseObj.setHiddenField("internal", runtime.wrap(hidden(promise)))

      # 4. Set promise.[[PromiseState]] to pending.
      promise.state = PromiseState.Pending

      # 5. Set promise.[[PromiseResult]] to empty.
      promise.res = none(JSValue)

      # 6. Set promise.[[PromiseFulfillReactions]] to a new empty List.
      promise.fulfillReactions = sequence(runtime, @[])

      # 7. Set promise.[[PromiseRejectReactions]] to a new empty List.
      promise.rejectReactions = sequence(runtime, @[])

      # 8. Set promise.[[PromiseIsHandled]] to false.
      promise.isHandled = false

      # 9. Let resolvingFuncs be CreateResolvingFunctions(promise).
      let resolvingFuncs = CreateResolvingFunctions(runtime, promiseObj)

      # 10. Let completion be Completion(Call(executor, undefined, « resolvingFuncs.[[Resolve]], resolvingFuncs.[[Reject]] »)).
      let completion = runtime.call(
        executor,
        this = undefined(runtime),
        @[resolvingFuncs.resolve, resolvingFuncs.reject],
      )

      # 11. If completion is an abrupt completion, then
      # HACK: This isn't a good way to check for an abrupt completion o_o
      if *runtime.vm.registers.error:
        # a. Perform ? Call(resolvingFuncs.[[Reject]], undefined, « completion.[[Value]] »).
        runtime.callNoRetval(
          resolvingFuncs.reject, this = undefined(runtime), @[completion]
        )

      # 12. Return promise.
      ret promiseObj
    ,
  )
