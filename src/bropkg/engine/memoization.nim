# A super fast stylesheet language for cool kids
#
# This module implements a cache system
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[critbits, hashes, jsonutils, json]
from ./ast import Node

export hashes

type
  MCall* = CritBitTree[Node] # ntCall
  MVar* = CritBitTree[Node] # ntVariable

proc hashed*(nstr: string): Hash = nstr.hash

proc isMemoized*(memo: CritBitTree, ident: Hash): bool =
  ## Checks if `ident` Hash is available in `memo` tree 
  result = memo.contains($(ident))

proc memoized*(memo: CritBitTree, ident: Hash): Node =
  ## Get a memoized node from `memo` tree. Returns `nil` when not found.
  try: memo[$(ident)]
  except KeyError: nil

proc memoize*(memo: var CritBitTree, ident: Hash, node: Node) =
  ## Store a new `node` using hashed `ident`
  memo[$(ident)] = node

proc delete*(memo: CritBitTree, ident: Hash) =
  ## Delete hashed `ident` from `memo`.
  ## If the `ident` does not exists, nothing happens.
  memo.excl($(ident))