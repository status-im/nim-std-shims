## Copyright (c) 2021 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements BASE10 (decimal) encoding and decoding procedures.
##
## Encoding procedures are adopted versions of C functions described here:
## # https://www.facebook.com/notes/facebook-engineering/three-optimization-tips-for-c/10151361643253920
import results
export results

{.push raises: [Defect].}

type
  Base10* = object

{.push overflowChecks: off.}
proc decode*[A: byte|char](B: typedesc[Base10], T: typedesc[SomeUnsignedInt],
                           src: openarray[A]): Result[T, cstring] =
  ## Convert base10 encoded string or array of bytes to unsigned integer.
  const
    MaxValue = T(high(T) div 10)
    MaxNumber = T(high(T) - MaxValue * 10)

  if len(src) == 0:
    return err("Missing decimal value")
  var v = T(0)
  for i in 0 ..< len(src):
    let d =
      when A is char:
        if src[i] >= char(0x30'i8) and src[i] <= char(0x39'i8):
          int(int8(src[i]) - 0x30'i8)
        else:
          -1
      else:
        if src[i] >= 0x30'u8 and src[i] <= 0x39'u8:
          int(src[i] - 0x30'u8)
        else:
          -1
    if d < 0:
      return err("Non-decimal character encountered")
    if v > MaxValue or (v == MaxValue and T(d) > MaxNumber):
      return err("Integer overflow")
    v = (v shl 3) + (v shl 1) + T(d)
  ok(v)
{.pop.}

proc encodedLength*(B: typedesc[Base10], value: SomeUnsignedInt): int =
  ## Procedure returns number of characters needed to encode integer ``value``.
  when type(value) is uint8:
    if value < 10'u8:
      return 1
    if value < 100'u8:
      return 2
    3
  elif type(value) is uint16:
    if value < 10'u16:
      return 1
    if value < 100'u16:
      return 2
    if value < 1000'u16:
      return 3
    if value < 10000'u16:
      return 4
    5
  elif type(value) is uint32:
    const
      P04 = 1_0000'u32
      P05 = 1_0000_0'u32
      P06 = 1_0000_00'u32
      P07 = 1_0000_000'u32
      P08 = 1_0000_0000'u32
      P09 = 1_0000_0000_0'u32
    if value < 10'u32:
      return 1
    if value < 100'u32:
      return 2
    if value < 1000'u32:
      return 3
    if value < P08:
      if value < P06:
        if value < P04:
          return 4
        return 5 + (if value >= P05: 1 else: 0)
      return 7 + (if value >= P07: 1 else: 0)
    9 + (if value >= P09: 1 else: 0)
  elif type(value) is uint64:
    const
      P04 = 1_0000'u64
      P05 = 1_0000_0'u64
      P06 = 1_0000_00'u64
      P07 = 1_0000_000'u64
      P08 = 1_0000_0000'u64
      P09 = 1_0000_0000_0'u64
      P10 = 1_0000_0000_00'u64
      P11 = 1_0000_0000_000'u64
      P12 = 1_0000_0000_0000'u64
    if value < 10'u64:
      return 1
    if value < 100'u64:
      return 2
    if value < 1000'u64:
      return 3
    if value < P12:
      if value < P08:
        if value < P06:
          if value < P04:
            return 4
          return 5 + (if value >= P05: 1 else: 0)
        return 7 + (if value >= P07: 1 else: 0)
      if value < P10:
        return 9 + (if value >= P09: 1 else: 0)
      return 11 + (if value >= P11: 1 else: 0)
    return 12 + B.encodedLength(value div P12)

proc encode[A: byte|char](B: typedesc[Base10], value: SomeUnsignedInt,
                          output: var openarray[A],
                          length: int): Result[int, cstring] =
  const Digits = cstring(
    "0001020304050607080910111213141516171819" &
    "2021222324252627282930313233343536373839" &
    "4041424344454647484950515253545556575859" &
    "6061626364656667686970717273747576777879" &
    "8081828384858687888990919293949596979899"
  )

  if len(output) < length:
    return err("Not enough space to store decimal value")

  var v = value
  var next = length - 1

  while v >= type(value)(100):
    let index = int((v mod type(value)(100)) shl 1)
    v = v div type(value)(100)
    when A is char:
      output[next] = Digits[index + 1]
      output[next - 1] = Digits[index]
    else:
      output[next] = byte(Digits[index + 1])
      output[next - 1] = byte(Digits[index])
    dec(next, 2)

  if v < type(value)(10):
    when A is char:
      output[next] = char(ord('0') + (v and type(value)(0x0F)))
    else:
      output[next] = byte('0') + byte(v and type(value)(0x0F))
  else:
    let index = int(v) shl 1
    when A is char:
      output[next] = Digits[index + 1]
      output[next - 1] = Digits[index]
    else:
      output[next] = byte(Digits[index + 1])
      output[next - 1] = byte(Digits[index])
  ok(length)

proc encode*[A: byte|char](B: typedesc[Base10], value: SomeUnsignedInt,
                           output: var openarray[A]): Result[int, cstring] =
  ## Encode integer value to array of characters or bytes.
  B.encode(value, output, B.encodedLength(value))

proc toString*(B: typedesc[Base10], value: SomeUnsignedInt): string =
  ## Encode integer value ``value`` to string.
  var buf = newString(B.encodedLength(value))
  # Buffer of proper size is allocated, so error is not possible
  discard B.encode(value, buf, len(buf))
  buf

proc toBytes*(B: typedesc[Base10], value: SomeUnsignedInt): seq[byte] =
  ## Encode integer value ``value`` to sequence of bytes.
  var buf = newSeq[byte](B.encodedLength(value))
  # Buffer of proper size is allocated, so error is not possible
  discard B.encode(value, buf, len(buf))
  buf
