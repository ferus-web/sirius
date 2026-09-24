## Implementation of `Promise`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, options]
import
  components/js/runtime/[arguments, atom_helpers, bridge, construction, types, wrapping],
  components/js/runtime/abstract/[callables, equating],
  components/js/stdlib/[errors_common, errors],
  components/js/stdlib/types/std_string_type,
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

  PromiseCapabilityObj = object
    ## https://tc39.es/ecma262/#sec-promisecapability-records
    ## A PromiseCapability Record is a Record used to encapsulate a Promise or promise-like object along with the functions that are capable of resolving or rejecting that promise.
    ## PromiseCapability Records are produced by the NewPromiseCapability abstract operation.
    promise*: Promise
    resolve*, reject*: JSValue

  PromiseCapability* = ptr PromiseCapabilityObj

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

func HostMakeJobCallback*(callback: JSValue): JobCallback =
  ## https://tc39.es/ecma262/#sec-hostmakejobcallback

  # 1. Return the JobCallback Record { [[Callback]]: callback, [[HostDefined]]: empty }.
  JobCallback(callback: callback, hostDefined: none(JSValue))

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
      if not runtime.isSpecObject(resolution):
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

proc NewPromiseCapability*(rt: Runtime, ctor: JSValue): PromiseCapability =
  ## https://tc39.es/ecma262/#sec-newpromisecapability

  # TODO: 1. If IsConstructor(ctor) is false, throw a TypeError exception.

  # 2. NOTE: ctor is assumed to be a constructor function that supports the parameter conventions of the Promise constructor (see 27.5.3.1).

  # 3. Let resolvingFuncs be the Record { [[Resolve]]: undefined, [[Reject]]: undefined }.
  let resolvingFuncs = rt.realm.heap.allocate(ResolvingFunctionsRecord)
  resolvingFuncs.resolve = undefined(rt)
  resolvingFuncs.reject = undefined(rt)

  # 4. Let executorClosure be a new Abstract Closure with parameters (resolve, reject) that captures resolvingFuncs and performs the following steps when called:
  let executorClosure = nativeCallable(
    rt,
    proc() =
      let
        runtime = rt # HACK: Code smell :(
        resolve = &runtime.argument(1)
        reject = &runtime.argument(2)

      # a. If resolvingFuncs.[[Resolve]] is not undefined, throw a TypeError exception.
      if not resolvingFuncs.resolve.isUndefined:
        rt.typeError("Promise's Resolve function must be undefined")
        return

      # b. If resolvingFuncs.[[Reject]] is not undefined, throw a TypeError exception.
      if not resolvingFuncs.reject.isUndefined:
        rt.typeError("Promise's Reject function must be undefined")
        return

      # c. Set resolvingFuncs.[[Resolve]] to resolve.
      resolvingFuncs.resolve = resolve

      # d. Set resolvingFuncs.[[Reject]] to reject.
      resolvingFuncs.reject = resolve

      # e. Return NormalCompletion(undefined).
      ret undefined(rt)
    ,
  )

  # 5. Let executor be CreateBuiltinFunction(executorClosure, 2, "", « »).
  let executor = executorClosure

  # 6. Let promise be ? Construct(ctor, « executor »).
  let promise = rt.call(ctor, this = undefined(rt), arguments = @[executor])

  # 7. If IsCallable(resolvingFuncs.[[Resolve]]) is false, throw a TypeError exception.
  if not IsCallable(rt, resolvingFuncs.resolve):
    rt.typeError("Promise's Resolve function was not set by executor")
    return

  # 8. If IsCallable(resolvingFuncs.[[Reject]]) is false, throw a TypeError exception.
  if not IsCallable(rt, resolvingFuncs.reject):
    rt.typeError("Promise's Reject function was not set by executor")
    return

  # 9. Return the PromiseCapability Record { [[Promise]]: promise, [[Resolve]]: resolvingFuncs.[[Resolve]], [[Reject]]: resolvingFuncs.[[Reject]] }.
  let record = rt.realm.heap.allocate(PromiseCapabilityObj)
  record.promise = &promise.getPrivateObject(Promise)
  record.reject = resolvingFuncs.reject
  record.resolve = resolvingFuncs.resolve

  record

proc IsPromise*(rt: Runtime, value: JSValue): bool =
  ## https://tc39.es/ecma262/#sec-ispromise
  ## The abstract operation IsPromise takes argument arg (an ECMAScript language value) and returns a Boolean. It checks for the promise brand on an object.

  # 1. If arg is not an Object, return false.
  if not rt.isSpecObject(value):
    return false

  # 2. If arg does not have a [[PromiseState]] internal slot, return false.
  if not *value.getPrivateObject(Promise):
    return false

  # 3. Return true.
  true

proc toJSPromise*(rt: Runtime, promise: Promise): JSValue =
  let obj = rt.createObjFromType(JSPromise)
  obj.setHiddenField("internal", rt.wrap(hidden(promise)))

  obj

proc PerformPromiseThen*(
    rt: Runtime,
    promise: Promise,
    onFulfilled, onRejected: JSValue,
    resultCapability: Option[PromiseCapability],
): JSValue =
  ## https://tc39.es/ecma262/#sec-performpromisethen

  # 1. Assert: IsPromise(promise) is true.
  # TODO: 2. If resultCapability is not present, then
  # TODO: a. Set resultCapability to undefined.

  let onFulfilledJobCallback =
    if not IsCallable(rt, onFulfilled):
      # 3. If IsCallable(onFulfilled) is false, then
      # a. Let onFulfilledJobCallback be empty.
      none(JobCallback)
    else:
      # 4. Else,
      # a. Let onFulfilledJobCallback be HostMakeJobCallback(onFulfilled).
      some(HostMakeJobCallback(onFulfilled))

  let onRejectedJobCallback =
    if not IsCallable(rt, onRejected):
      # 5. If IsCallable(onRejected) is false, then
      # a. Let onRejectedJobCallback be empty.
      none(JobCallback)
    else:
      # 6. Else,
      # a. Let onRejectedJobCallback be HostMakeJobCallback(onRejected).
      some(HostMakeJobCallback(onRejected))

  # 7. Let fulfillReaction be the PromiseReaction Record { [[Capability]]: resultCapability, [[Type]]: fulfill, [[Handler]]: onFulfilledJobCallback }.
  let fulfillReaction = rt.realm.heap.allocate(PromiseReactionObj)
  fulfillReaction.capability = resultCapability
  fulfillReaction.kind = PromiseReactionKind.Fulfill
  fulfillReaction.handler = onFulfilledJobCallback

  # 8. Let rejectReaction be the PromiseReaction Record { [[Capability]]: resultCapability, [[Type]]: reject, [[Handler]]: onRejectedJobCallback }.
  let rejectReaction = rt.realm.heap.allocate(PromiseReactionObj)
  rejectReaction.capability = resultCapability
  rejectReaction.kind = PromiseReactionKind.Reject
  rejectReaction.handler = onRejectedJobCallback

  let
    fulfillReactionObj = obj(rt)
    rejectReactionObj = obj(rt)

  fulfillReactionObj.setHiddenField("internal", rt.wrap(hidden(fulfillReaction)))
  rejectReactionObj.setHiddenField("internal", rt.wrap(hidden(rejectReaction)))

  case promise.state
  of PromiseState.Pending:
    # 9. If promise.[[PromiseState]] is pending, then
    # a. Append fulfillReaction to promise.[[PromiseFulfillReactions]].
    promise.fulfillReactions.sequence &= fulfillReactionObj

    # b. Append rejectReaction to promise.[[PromiseRejectReactions]].
    promise.rejectReactions.sequence &= rejectReactionObj
  of PromiseState.Fulfilled:
    # 10. Else if promise.[[PromiseState]] is fulfilled, then
    # a. Let value be promise.[[PromiseResult]].
    let value = promise.res

    # b. Let fulfillJob be NewPromiseReactionJob(fulfillReaction, value).
    let fulfillJob = NewPromiseReactionJob(rt, fulfillReactionObj, &value)

    # c. Perform HostEnqueuePromiseJob(fulfillJob.[[Job]], fulfillJob.[[Realm]]).
    HostEnqueuePromiseJob(rt, fulfillJob)
  of PromiseState.Rejected:
    # 11. Else,
    # a. Assert: promise.[[PromiseState]] is rejected.

    # b. Let reason be promise.[[PromiseResult]].
    let reason = promise.res

    # c. If promise.[[PromiseIsHandled]] is false, perform HostPromiseRejectionTracker(promise, "handle").
    if not promise.isHandled:
      # TODO: HostPromiseRejectionTracker(rt, promise, "handle")
      discard

    # d. Let rejectJob be NewPromiseReactionJob(rejectReaction, reason).
    let rejectJob = NewPromiseReactionJob(rt, rejectReactionObj, &reason)

    # e. Perform HostEnqueuePromiseJob(rejectJob.[[Job]], rejectJob.[[Realm]]).
    HostEnqueuePromiseJob(rt, rejectJob)

  # 12. Set promise.[[PromiseIsHandled]] to true.
  promise.isHandled = true

  # 13. If resultCapability is undefined, return undefined.
  if !resultCapability:
    return undefined(rt)

  # 14. Return resultCapability.[[Promise]].
  toJSPromise(rt, (&resultCapability).promise)

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

      # HACK: Make a better way to ensure the interpreter doesn't casually waltz past into
      # our rollback point after executing the executor
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

  runtime.definePrototypeFn(
    JSPromise,
    "then",
    proc(this: JSValue) =
      ## 27.5.5.4 Promise.prototype.then ( onFulfilled, onRejected )
      ## https://tc39.es/ecma262/#sec-promise.prototype.then

      let
        onFulfilled = &runtime.argument(1)
        onRejected = &runtime.argument(2)

      # 1. Let promise be the this value.
      let promise = this

      # 2. If IsPromise(promise) is false, throw a TypeError exception.
      if not IsPromise(runtime, promise):
        runtime.typeError("Promise.prototype.then() only works with Promise objects")
        return

      # 3. Let ctor be ? SpeciesConstructor(promise, %Promise%).
      let ctor = runtime.getConstructor(JSPromise)

      # 4. Let resultCapability be ? NewPromiseCapability(ctor).
      let resultCapability =
        NewPromiseCapability(runtime, nativeCallable(runtime, &ctor))

      # 5. Return PerformPromiseThen(promise, onFulfilled, onRejected, resultCapability).
      ret PerformPromiseThen(
        runtime,
        &promise.getPrivateObject(Promise),
        onFulfilled,
        onRejected,
        some(resultCapability),
      )
    ,
  )
