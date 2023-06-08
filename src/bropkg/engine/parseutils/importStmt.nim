proc parseImport(p: var Parser, scope: ScopeTable = nil): Node = 
  if p.next.kind == tkString:
    walk p # walk to file name
  let fname = addFileExt(p.curr.value, "bass")
  var fpath = fname.absolutePath
  if fileExists(fpath):
    result = newImport(fpath)
    if likely(p.imports.hasKey(fpath) == false):
      p.memparser.insert(fpath, nil)
      p.imports[fpath] = result
      var thr: Thread[(string, Memparser)]
      createThread(thr, partialThread, (fpath, p.memparser))
      joinThread(thr)
      p.memparser.withValue(fpath):
        p.imports[fpath].importNodes = value[].nodes
    else:
      result.importNodes = p.imports[fpath].importNodes
    walk p
    # if pp.hasErrors:
    #   for error in pp.logger.errors:
    #     display(error)
    #   display(" 👉 " & pp.logger.filePath)
    #   return
    # if pp.memtable.len != 0:
    #   for k, v in pp.memtable.pairs:
    #     if not p.memtable.hasKey(k):
    #       p.memtable[k] = v
    #     else:
    #       error(DuplicateVarDeclaration, p.curr, "$" & k)
    #       return
    # result = newImport(pp.program.nodes, fpath)
    # walk p
  else:
    error(ImportErrorFileNotFound, p.curr, fname)