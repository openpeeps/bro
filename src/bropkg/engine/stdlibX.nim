# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import ./ast
import std/[tables, macros, os, macrocache,
          options, strutils]

export options

{.pragma: nim, cdecl, noSideEffect, gcsafe.}

type
  Function = object
    id: int
    value: pointer
    functionType: type
    argsType: seq[NodeType]
    returnType: NodeType # default ntVoid

  Source = distinct string
  Module = CritBitTree[Function]
  Stdlib* = CritBitTree[(Module, Source)]

const
  counter = CacheCounter("counter")
  basePath = getProjectPath() / "bropkg" / "stdlib"

  strutilsPath = basePath / "strings.bass"
  strutilsCode = staticRead(strutilsPath)

func typeId(tp: type): int =
  const id = counter.value
  static:
    inc counter
  id

proc fn*[T](p: T): Function =
  Function(id: T.typeId, value: cast[pointer](p))

proc fn*[T](args: seq[NodeType], returnType = ntVoid, p: T): Function =
  Function(
    id: T.typeId,
    argsType: args,
    returnType: returnType,
    value: cast[pointer](p)
  )

var strtable {.threadvar.}: Module
var stdlib {.threadvar.}: Stdlib

proc call*(lib: Module, fnName: string, fn: type): Option[fn] =
  let f = lib[fnName]
  if fn.typeId != f.id:
    none(fn)
  else:
    some(cast[fn](f.value))

proc get*(lib: Module, fnName: string, fn: type): tuple[returnType: NodeType, argsType: seq[NodeType]] =
  let f = lib[fnName]
  if fn.typeId == f.id:
    return (f.returnType, f.argsType)

proc strings*(): Module = stdlib["std/strings"][0]

type
  strCountFn* = proc (str: string, sub: string): bool {.nim.}
  strContainsFn* = proc (str: string, sub: string): bool {.nim.}
  strCapitalizeFn* = proc (s: string): string {.nim.}
  strEndsWithFn* = proc (arg: openarray[Node]): bool {.nim.}
  strStartsWithFn* = proc (s: string, prefix: string): bool {.nim.}
  strFindFn* = proc (str, sub: string, start = 0, last = - 1): int {.nim.}

# strtable["count"] = fn:
#   proc (str: string, sub: char): int {.nim.} = count(str, sub)

# strtable["capitalize"] =
#   fn(@[ntString], ntString,
#     proc (s: string): string {.nim.} = capitalizeAscii(s))

# strtable["startsWith"] =
#   fn(@[ntString, ntString], ntBool,
#     proc (s: string, prefix: string): bool {.nim.} = startsWith(s, prefix))

strtable["endsWith"] =
  fn(@[ntString, ntString], ntBool,
    proc (arg: openarray[Node]): Node {.nim.} =
      newBool(endsWith(arg[0].sVal, arg[1].sVal)))

# strtable["find"] = fn:
#   proc (s: string, sub: char, start: Natural = 0, last = -1): int = find(s, sub, start, last)

# strtable["replace"] = fn:
#   proc (s, sub, by: string): string = replace(s, sub, by)


# strtable["contains"] = fn:
#   proc (str: string, sub: string): bool {.nim.} =
#     str.contains(sub)

# strtable["find"] = fn:
#   proc (str, sub: string, start = 0, last = - 1): int {.nim.} =
#     str.find(sub, start, last)

stdlib["std/strings"] = (strtable, Source(strutilsCode))

proc std*(lib: string): Module {.raises: KeyError.} =
  ## Retrieves a module from standard library
  return stdlib[lib][0]

macro newModule(name, functions: untyped) =
  discard

newModule strings:
  echo "x"

proc exists*(libName: string): bool = stdlib.hasKey(libName)
proc getModule*(libName: string): (Module, Source) = stdlib[libName]