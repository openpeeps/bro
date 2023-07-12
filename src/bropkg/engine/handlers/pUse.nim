import std/[macrocache, options]
import std/strutils

const counter = CacheCounter("counter")

func typeID(tp: type): int =
  const id = counter.value
  static:
    inc counter
  id

{.pragma: dynProc, cdecl, noSideEffect, gcsafe, locks:0.}
# https://stackoverflow.com/questions/68217774/how-can-i-create-a-lookup-table-of-different-procedures-in-nim

type
  Function* = object
    id: int
    value: pointer

proc getId*(f: Function): int = f.id

proc fn*[T](p: T): Function =
  Function(id: T.typeID, value: cast[pointer](p))

var strtable = newTable[string, Function]()
var stdlib = newTable[string, TableRef[string, Function]]()

proc call*(fnName: string, fnType: type): Option[fnType] =
  let f = strtable[fnName]
  if fnType.typeID != f.id:
    none(fnType)
  else:
    some(cast[fnType](f.value))

type strCountFn = proc (str: string, sub: string): bool {.dynProc.}
strtable["count"] = fn:
  proc (str: string, sub: char): int {.dynProc.} =
    str.count(sub)

type strContainsFn = proc (str: string, sub: string): bool {.dynProc.}
strtable["contains"] = fn:
  proc (str: string, sub: string): bool {.dynProc.} =
    str.contains(sub)

stdlib["strutils"] = strtable

# echo call("contains", strContainsFn).get()("Ala bala portocala", "portocala")

proc parseUse(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  ## Parse a new `@use` statement. This is used to load
  ## standard library modules or mixins, functions and variables
  ## from other Stylesheets
  walk p # @use
  if p.curr.kind == tkIdentifier:
    # check if request a std
    if p.curr.value == "std":
      if p.next.kind == tkDivide:
        walk p, 2
        if p.curr.kind == tkIdentifier and stdlib.hasKey(p.curr.value):
          let libName = p.curr
          echo libName
        else:
          echo "error, unknown module"