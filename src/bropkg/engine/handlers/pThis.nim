newPrefixProc "parseThis":
  ## parse `this` symbol inside a selector block
  if p.next.kind == tkDotExpr:
    echo p.curr
    walk p, 2
