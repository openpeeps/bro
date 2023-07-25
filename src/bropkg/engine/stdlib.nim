# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[tables, macrocache, options, strutils]

{.pragma: nim, cdecl, noSideEffect, gcsafe.}

type
  Function* = object
    id: int
    value: pointer
  StandardLibrary* = Table[string, TableRef[string, Function]]

const counter = CacheCounter("counter")

func typeId(tp: type): int =
  const id = counter.value
  static:
    inc counter
  id

proc fn*[T](p: T): Function =
  Function(id: T.typeId, value: cast[pointer](p))

var strtable = newTable[string, Function]()
var stdlib = newTable[string, TableRef[string, Function]]()

proc call*(fnName: string, fn: type): Option[fn] =
  let f = strtable[fnName]
  if fn.typeId != f.id:
    none(fn)
  else:
    some(cast[fn](f.value))

type strCountFn = proc (str: string, sub: string): bool {.nim.}
strtable["count"] = fn:
  proc (str: string, sub: char): int {.nim.} =
    str.count(sub)

type strContainsFn = proc (str: string, sub: string): bool {.nim.}
strtable["contains"] = fn:
  proc (str: string, sub: string): bool {.nim.} =
    str.contains(sub)

type strFindFn = proc (str, sub: string, start = 0, last = - 1): int {.nim.}
strtable["find"] = fn:
  proc (str, sub: string, start = 0, last = - 1): int {.nim.} =
    str.find(sub, start, last)

stdlib["strings"] = strtable
