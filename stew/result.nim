# nim-result is also available stand-alone from https://github.com/arnetheduck/nim-result/

# Copyright (c) 2019 Jacek Sieka
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

type
  ResultError*[E] = object of ValueError
    ## Error raised when using `tryGet` value of result when error is set
    ## See also Exception bridge mode
    error*: E

  ResultDefect* = object of Defect
    ## Defect raised when accessing value when error is set and vice versa
    ## See also Exception bridge mode

  Result*[T, E] = object
    ## Result type that can hold either a value or an error, but not both
    ##
    ## # Example
    ##
    ## ```
    ## # It's convenient to create an alias - most likely, you'll do just fine
    ## # with strings or cstrings as error
    ##
    ## type R = Result[int, string]
    ##
    ## # Once you have a type, use `ok` and `err`:
    ##
    ## func works(): R =
    ##   # ok says it went... ok!
    ##   R.ok 42
    ## func fails(): R =
    ##   # or type it like this, to not repeat the type!
    ##   result.err "bad luck"
    ##
    ## if (let w = works(); w.isOk):
    ##   echo w[], " or use value: ", w.value
    ##
    ## # In case you think your callers want to differentiate between errors:
    ## type
    ##   Error = enum
    ##     a, b, c
    ##   type RE[T] = Result[T, Error]
    ##
    ## # In the expriments corner, you'll find the following syntax for passing
    ## # errors up the stack:
    ## func f(): R =
    ##   let x = ?works() - ?fails()
    ##   assert false, "will never reach"
    ##
    ## # If you provide this exception converter, this exception will be raised
    ## # on dereference
    ## func toException(v: Error): ref CatchableError = (ref CatchableError)(msg: $v)
    ## try:
    ##   RE[int].err(a)[]
    ## except CatchableError:
    ##   echo "in here!"
    ##
    ## ```
    ##
    ## See the tests for more practical examples, specially when working with
    ## back and forth with the exception world!
    ##
    ## # Potential benefits:
    ##
    ## * Handling errors becomes explicit and mandatory - goodbye "out of sight,
    ##   out of mind"
    ## * Errors are a visible part of the API - when they change, so must the
    ##   calling code and compiler will point this out - nice!
    ## * Errors are a visible part of the API - your fellow programmer is
    ##   reminded that things actually can go wrong
    ## * Jives well with Nim `discard`
    ## * Jives well with the new Defect exception hierarchy, where defects
    ##   are raised for unrecoverable errors and the rest of the API uses
    ##   results
    ## * Error and value return have similar performance characteristics
    ## * Caller can choose to turn them into exceptions at low cost - flexible
    ##   for libraries!
    ## * Mostly relies on simple Nim features - though this library is no
    ##   exception in that compiler bugs were discovered writing it :)
    ##
    ## # Potential costs:
    ##
    ## * Handling errors becomes explicit and mandatory - if you'd rather ignore
    ##   them or just pass them to some catch-all, this is noise
    ## * When composing operations, value must be lifted before funcessing,
    ##   adding potential verbosity / noise (fancy macro, anyone?)
    ## * There's no call stack captured by default (see also `catch` and
    ##   `capture`)
    ## * The extra branching may be more expensive for the non-error path
    ##   (though this can be minimized with PGO)
    ##
    ## The API visibility issue of exceptions can also be solved with
    ## `{.raises.}` annotations - as of now, the compiler doesn't remind
    ## you to do so, even though it knows what the right annotation should be.
    ## `{.raises.}` does not participate in generic typing, making it just as
    ## verbose but less flexible in some ways, if you want to type it out.
    ##
    ## Many system languages make a distinction between errors you want to
    ## handle and those that are simply bugs or unrealistic to deal with..
    ## handling the latter will often involve aborting or crashing the funcess -
    ## reliable systems like Erlang will try to relaunch it.
    ##
    ## On the flip side we have dynamic languages like python where there's
    ## nothing exceptional about exceptions (hello StopIterator). Python is
    ## rarely used to build reliable systems - its strengths lie elsewhere.
    ##
    ## # Exception bridge mode
    ##
    ## When the error of a `Result` is an `Exception`, or a `toException` helper
    ## is present for your error type, the "Exception bridge mode" is
    ## enabled and instead of raising `Defect`, we will raise the given
    ## `Exception` on access.
    ##
    ## This is an experimental feature that may be removed.
    ##
    ## # Other languages
    ##
    ## Result-style error handling seems pretty popular lately, specially with
    ## statically typed languages:
    ## Haskell: https://hackage.haskell.org/package/base-4.11.1.0/docs/Data-Either.html
    ## Rust: https://doc.rust-lang.org/std/result/enum.Result.html
    ## Modern C++: https://github.com/viboes/std-make/tree/master/doc/proposal/expected
    ## More C++: https://github.com/ned14/outcome
    ##
    ## Swift is interesting in that it uses a non-exception implementation but
    ## calls errors exceptions and has lots of syntactic sugar to make them feel
    ## that way by implicitly passing them up the call chain - with a mandatory
    ## annotation that function may throw:
    ## https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/ErrorHandling.html
    ##
    ## # Considerations for the error type
    ##
    ## * Use a `string` or a `cstring` if you want to provide a diagnostic for
    ##   the caller without an expectation that they will differentiate between
    ##   different errors. Callers should never parse the given string!
    ## * Use an `enum` to provide in-depth errors where the caller is expected
    ##   to have different logic for different errors
    ## * Use a complex type to include error-specific meta-data - or make the
    ##   meta-data collection a visible part of your API in another way - this
    ##   way it remains discoverable by the caller!
    ##
    ## A natural "error API" progression is starting with `Option[T]`, then
    ## `Result[T, cstring]`, `Result[T, enum]` and `Result[T, object]` in
    ## escalating order of complexity.
    ##
    ## # Other implemenations in nim
    ##
    ## There are other implementations in nim that you might prefer:
    ## * Either from nimfp: https://github.com/vegansk/nimfp/blob/master/src/fp/either.nim
    ## * result_type: https://github.com/kapralos/result_type/
    ##
    ## # Implementation notes
    ##
    ## This implementation is mostly based on the one in rust. Compared to it,
    ## there are a few differences - if know of creative ways to improve things,
    ## I'm all ears.
    ##
    ## * Rust has the enum variants which lend themselves to nice construction
    ##   where the full Result type isn't needed: `Err("some error")` doesn't
    ##   need to know value type - maybe some creative converter or something
    ##   can deal with this?
    ## * Nim templates allow us to fail fast without extra effort, meaning the
    ##   other side of `and`/`or` isn't evaluated unless necessary - nice!
    ## * Rust uses From traits to deal with result translation as the result
    ##   travels up the call stack - needs more tinkering - some implicit
    ##   conversions would be nice here
    ## * Pattern matching in rust allows convenient extraction of value or error
    ##   in one go.
    ##
    ## Relevant nim bugs:
    ## https://github.com/nim-lang/Nim/issues/13799

    case o: bool
    of false:
      e: E
    of true:
      v: T

func raiseResultError[T, E](self: Result[T, E]) {.noreturn.} =
  mixin toException

  when E is ref Exception:
    if self.e.isNil: # for example Result.default()!
      raise (ref ResultError[void])(msg: "Trying to access value with err (nil)")
    raise self.e
  elif compiles(toException(self.e)):
    raise toException(self.e)
  elif compiles($self.e):
    raise (ref ResultError[E])(
      error: self.e, msg: "Trying to access value with err: " & $self.e)
  else:
    raise (res ResultError[E])(msg: "Trying to access value with err", error: self.e)

func raiseResultDefect(m: string, v: auto) {.noreturn.} =
  if compiles($v): raise (ref ResultDefect)(msg: m & ": " & $v)
  else: raise (ref ResultDefect)(msg: m)

template checkOk(self: Result) =
  # TODO This condition is a bit odd in that it raises different exceptions
  #      depending on the type of E - this is done to support using Result as a
  #      bridge type that can transport Exceptions
  if not self.isOk:
    when E is ref Exception or compiles(toException(self.e)):
      raiseResultError(self)
    else:
      raiseResultDefect("Trying to acces value with err Result", self.e)

template ok*[T, E](R: type Result[T, E], x: auto): R =
  ## Initialize a result with a success and value
  ## Example: `Result[int, string].ok(42)`
  R(o: true, v: x)

template ok*[T, E](self: var Result[T, E], x: auto) =
  ## Set the result to success and update value
  ## Example: `result.ok(42)`
  self = ok(type self, x)

template err*[T, E](R: type Result[T, E], x: auto): R =
  ## Initialize the result to an error
  ## Example: `Result[int, string].err("uh-oh")`
  R(o: false, e: x)

template err*[T, E](self: var Result[T, E], x: auto) =
  ## Set the result as an error
  ## Example: `result.err("uh-oh")`
  self = err(type self, x)

template ok*(v: auto): auto = ok(typeof(result), v)
template err*(v: auto): auto = err(typeof(result), v)

template isOk*(self: Result): bool = self.o
template isErr*(self: Result): bool = not self.o

func map*[T, E, A](
    self: Result[T, E], f: proc(x: T): A): Result[A, E] {.inline.} =
  ## Transform value using f, or return error
  if self.isOk: result.ok(f(self.v))
  else: result.err(self.e)

func flatMap*[T, E, A](
    self: Result[T, E], f: proc(x: T): Result[A, E]): Result[A, E] {.inline.} =
  if self.isOk: f(self.v)
  else: Result[A, E].err(self.e)

func mapErr*[T: not void, E, A](
    self: Result[T, E], f: proc(x: E): A): Result[T, A] {.inline.} =
  ## Transform error using f, or return value
  if self.isOk: result.ok(self.v)
  else: result.err(f(self.e))

func mapConvert*[T0, E0](
    self: Result[T0, E0], T1: type): Result[T1, E0] {.inline.} =
  ## Convert result value to A using an conversion
  # Would be nice if it was automatic...
  if self.isOk: result.ok(T1(self.v))
  else: result.err(self.e)

func mapCast*[T0, E0](
    self: Result[T0, E0], T1: type): Result[T1, E0] {.inline.} =
  ## Convert result value to A using a cast
  ## Would be nice with nicer syntax...
  if self.isOk: result.ok(cast[T1](self.v))
  else: result.err(self.e)

template `and`*[T, E](self, other: Result[T, E]): Result[T, E] =
  ## Evaluate `other` iff self.isOk, else return error
  ## fail-fast - will not evaluate other if a is an error
  ##
  ## TODO: This API is unsafe due to potential multiple
  ## evaluation of the `self` parameter.
  if self.isOk:
    other
  else:
    type R = type(other)
    R.err(self.e)

template `or`*[T, E](self, other: Result[T, E]): Result[T, E] =
  ## Evaluate `other` iff not self.isOk, else return self
  ## fail-fast - will not evaluate other if a is a value
  ##
  ## TODO: This API is unsafe due to potential multiple
  ## evaluation of the `self` parameter.
  if self.isOk: self
  else: other

template catch*(body: typed): Result[type(body), ref CatchableError] =
  ## Catch exceptions for body and store them in the Result
  ##
  ## ```
  ## let r = catch: someFuncThatMayRaise()
  ## ```
  type R = Result[type(body), ref CatchableError]

  try:
    R.ok(body)
  except CatchableError as e:
    R.err(e)

template capture*[E: Exception](T: type, someExceptionExpr: ref E): Result[T, ref E] =
  ## Evaluate someExceptionExpr and put the exception into a result, making sure
  ## to capture a call stack at the capture site:
  ##
  ## ```
  ## let e: Result[void, ValueError] = void.capture((ref ValueError)(msg: "test"))
  ## echo e.error().getStackTrace()
  ## ```
  type R = Result[T, ref E]

  var ret: R
  try:
    # TODO is this needed? I think so, in order to grab a call stack, but
    #      haven't actually tested...
    if true:
      # I'm sure there's a nicer way - this just works :)
      raise someExceptionExpr
  except E as caught:
    ret = R.err(caught)
  ret

func `==`*[T0, E0, T1, E1](lhs: Result[T0, E0], rhs: Result[T1, E1]): bool {.inline.} =
  if lhs.isOk != rhs.isOk:
    false
  elif lhs.isOk:
    lhs.v == rhs.v
  else:
    lhs.e == rhs.e

func get*[T: not void, E](self: Result[T, E]): T {.inline.} =
  ## Fetch value of result if set, or raise Defect
  ## Exception bridge mode: raise given Exception instead
  ## See also: Option.get
  checkOk(self)
  self.v

func tryGet*[T: not void, E](self: Result[T, E]): T {.inline.} =
  ## Fetch value of result if set, or raise
  ## When E is an Exception, raise that exception - otherwise, raise a ResultError[E]
  if not self.isOk: self.raiseResultError
  self.v

func get*[T, E](self: Result[T, E], otherwise: T): T {.inline.} =
  ## Fetch value of result if set, or return the value `otherwise`
  if self.isErr: otherwise
  else: self.v

func get*[T, E](self: var Result[T, E]): var T {.inline.} =
  ## Fetch value of result if set, or raise Defect
  ## Exception bridge mode: raise given Exception instead
  ## See also: Option.get
  checkOk(self)
  self.v

template `[]`*[T, E](self: Result[T, E]): T =
  ## Fetch value of result if set, or raise Defect
  ## Exception bridge mode: raise given Exception instead
  self.get()

template `[]`*[T, E](self: var Result[T, E]): var T =
  ## Fetch value of result if set, or raise Defect
  ## Exception bridge mode: raise given Exception instead
  self.get()

template unsafeGet*[T, E](self: Result[T, E]): T =
  ## Fetch value of result if set, undefined behavior if unset
  ## See also: Option.unsafeGet
  assert isOk(self)
  self.v

func expect*[T: not void, E](self: Result[T, E], m: string): T =
  ## Return value of Result, or raise a `Defect` with the given message - use
  ## this helper to extract the value when an error is not expected, for example
  ## because the program logic dictates that the operation should never fail
  ##
  ## ```nim
  ## let r = Result[int, int].ok(42)
  ## # Put here a helpful comment why you think this won't fail
  ## echo r.expect("r was just set to ok(42)")
  ## ```
  if not self.isOk():
    raiseResultDefect(m, self.error)
  self.v

func expect*[T: not void, E](self: var Result[T, E], m: string): var T =
  if not self.isOk():
    raiseResultDefect(m, self.error)
  self.v

func `$`*(self: Result): string =
  ## Returns string representation of `self`
  if self.isOk: "Ok(" & $self.v & ")"
  else: "Err(" & $self.e & ")"

func error*[T, E](self: Result[T, E]): E =
  ## Fetch error of result if set, or raise Defect
  if not self.isErr:
    when T is not void:
      raiseResultDefect("Trying to access error when value is set", self.v)
    else:
      raise (ref ResultDefect)(msg: "Trying to access error when value is set")

  self.e

template value*[T, E](self: Result[T, E]): T = self.get()
template value*[T, E](self: var Result[T, E]): T = self.get()

template valueOr*[T, E](self: Result[T, E], def: T): T =
  ## Fetch value of result if set, or supplied default
  ## default will not be evaluated iff value is set
  self.get(def)

# void support

template ok*[E](R: type Result[void, E]): auto =
  ## Initialize a result with a success and value
  ## Example: `Result[int, string].ok(42)`
  R(o: true)

template ok*[E](self: var Result[void, E]) =
  ## Set the result to success and update value
  ## Example: `result.ok(42)`
  self = (type self).ok()

template ok*(): auto = ok(typeof(result))
template err*(): auto = err(typeof(result))

# TODO:
# Supporting `map` and `get` operations on a `void` result is quite
# an unusual API. We should provide some motivating examples.

func map*[E, A](
    self: Result[void, E], f: proc(): A): Result[A, E] {.inline.} =
  ## Transform value using f, or return error
  if self.isOk: result.ok(f())
  else: result.err(self.e)

func flatMap*[E, A](
    self: Result[void, E], f: proc(): Result[A, E]): Result[A, E] {.inline.} =
  if self.isOk: f(self.v)
  else: Result[A, E].err(self.e)

func mapErr*[E, A](
    self: Result[void, E], f: proc(x: E): A): Result[void, A] {.inline.} =
  ## Transform error using f, or return value
  if self.isOk: result.ok()
  else: result.err(f(self.e))

func map*[T, E](
    self: Result[T, E], f: proc(x: T)): Result[void, E] {.inline.} =
  ## Transform value using f, or return error
  if self.isOk: f(self.v); result.ok()
  else: result.err(self.e)

func get*[E](self: Result[void, E]) {.inline.} =
  ## Fetch value of result if set, or raise
  ## See also: Option.get
  checkOk(self)

func tryGet*[E](self: Result[void, E]) {.inline.} =
  ## Fetch value of result if set, or raise a CatchableError
  if not self.isOk: self.raiseResultError

template `[]`*[E](self: Result[void, E]) =
  ## Fetch value of result if set, or raise
  self.get()

template unsafeGet*[E](self: Result[void, E]) =
  ## Fetch value of result if set, undefined behavior if unset
  ## See also: Option.unsafeGet
  assert not self.isErr

func expect*[E](self: Result[void, E], msg: string) =
  if not self.isOk():
    raise (ref ResultDefect)(msg: msg)

func `$`*[E](self: Result[void, E]): string =
  ## Returns string representation of `self`
  if self.isOk: "Ok()"
  else: "Err(" & $self.e & ")"

template value*[E](self: Result[void, E]) = self.get()
template value*[E](self: var Result[void, E]) = self.get()

template `?`*[T, E](self: Result[T, E]): T =
  ## Early return - if self is an error, we will return from the current
  ## function, else we'll move on..
  ##
  ## ```
  ## let v = ? funcWithResult()
  ## echo v # prints value, not Result!
  ## ```
  ## Experimental
  # TODO the v copy is here to prevent multiple evaluations of self - could
  #      probably avoid it with some fancy macro magic..
  let v = (self)
  if v.isErr: return err(typeof(result), v.error)

  v.value
