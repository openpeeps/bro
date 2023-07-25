# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseThis":
  ## parse `this` symbol inside a selector block
  if p.next.kind == tkDotExpr:
    echo p.curr
    walk p, 2
