# A super fast stylesheet language for cool kids
#
# This module implements a cache system
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[critbits, hashes]
from ./ast import Node

type
  MCall* = CritBitTree[Node] # ntCall
  MVar* = CritBitTree[Node] # ntVariable

proc isMemoized*(memo: CritBitTree, ident: string): bool =
  result = memo.contains($hash(ident))

proc getMemoized*(memo: CritBitTree, ident: string): Node =
  try: memo[$hash(ident)]
  except KeyError: nil

proc memoize*(memo: var CritBitTree, ident: string, node: Node) =
  memo[$hash(ident)] = node