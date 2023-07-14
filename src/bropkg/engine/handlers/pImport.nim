newPrefixProc "parseImport":
  # Parse a new `@import x` statement
  if p.next is tkIdentifier:
    walk p
    if p.curr.value == "std" and p.next is tkDivide:
      # parse import from standard library
      walk p, 2
      if p.curr is tkIdentifier:
        discard
      elif p.curr is tkLB:
        # parse a list of imports
        walk p # [
        result = newImport("")
        while p.curr isnot tkRB:
          if p.curr is tkIdentifier:
            if likely(p.curr.value notin p.imports):
              p.imports["std" / p.curr.value] = newImport("std" / p.curr.value)
              walk p
            else: errorWithArgs(useDuplicateModule, p.curr, [p.curr.value])
          if p.curr is tkComma:
            walk p
          elif p.curr isnot tkRB:
            error(missingRB, p.curr)
        walk p # ]
    else:
      # parse import from local project
      let fname = addFileExt(p.curr.value, "bass")
      var fpath = fname.absolutePath
      if fileExists(fpath):
        result = newImport(fpath)
        if likely(p.imports.hasKey(fpath) == false):
          p.stylesheets.insert(fpath, nil)
          p.imports[fpath] = result
          var thr: Thread[(string, Stylesheets)]
          createThread(thr, importThread, (fpath, p.stylesheets))
          joinThread(thr)
          p.stylesheets.withValue(fpath):
            p.imports[fpath].importNodes = value[].nodes
          result.importNodes = p.imports[fpath].importNodes
        # else:
          # result.importNodes = p.imports[fpath].importNodes
        walk p

proc parseImportFrom(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse a new `@from x import y` statement
  discard