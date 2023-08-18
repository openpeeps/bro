# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

const broCachePath = getCacheDir("bro-lang")

when compileOption("app", "console"):
  proc hashast(path: string): string = getMD5(path) & ".ast"
  proc getCachePath*(d, f: string): string =
    broCachePath / getMD5(d) / hashast(f)
  
  proc cache(path, dirPath: string, stylesheet: Stylesheet) =
    {.gcsafe.}:
      let projectDirPath = getMD5(dirPath)
      discard existsOrCreateDir(broCachePath)
      discard existsOrCreateDir(broCachePath / projectDirPath)
      writeFile(getCachePath(dirPath, path), toFlatty(stylesheet).compress)

  proc cached(path, dirPath: string): Stylesheet =
    {.gcsafe.}:
      let ast = readFile(broCachePath / getMD5(dirPath) / hashast(path))
      ast.uncompress().fromFlatty(Stylesheet)

  proc cacheRefresh*(p: var Parser, path, dirPath: string): bool =
    if not p.cacheEnabled: return true # returning true will ignore caching
    let cachedPath = getCachePath(dirPath, path)
    if fileExists(cachedPath):
      return path.getLastModificationTime > cachedPath.getLastModificationTime
    result = true

  proc cacheExists(path: string): bool =
    fileExists(broCachePath / getMD5(path))

proc importer(fpath, dirPath: string, results: ptr Table[string, Stylesheet],
  L: ptr TicketLock, isStdlib = false, code: SourceCode = SourceCode("")) {.gcsafe, thread.} =
  var p = Parser(
    filePath: fpath,
    dirPath: dirPath,
    program: Stylesheet(sourcePath: fpath),
    propsTable: initPropsTable(),
    logger: Logger(filePath: fpath),
  )
  p.lex = 
    if not isStdlib:
      newLexer(readFile(fpath))
    else:
      newLexer(code.string)
  p.program.setGlobalScope(ScopeTable())
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  while p.curr isnot tkEOF:
    if p.lex.hasError:
      p.logger.newError(internalError, p.curr.line, p.curr.col, false, [p.lex.getError])
    if p.hasErrors: break
    let node = p.parseRoot(excludeOnly = {tkExtend, tkPseudo, tkReturn})
    if likely(node != nil):
      add p.program.nodes, node
  p.lex.close()
  if likely(p.hasErrors == false):
    withLock L[]:
      results[][fpath] = p.getStylesheet
  else:
    for msg in p.logger.errors:
        display(msg)
    display(" 👉 " & p.logger.filePath)

proc importSystemModule(p: var Parser) =
  ## Make `std/system` available by default
  let sysid = "std/system"
  var sysImport = newImport()
  sysImport.modules.add(sysid)
  p.program.nodes.add(sysImport)
  var L = initTicketLock()
  importer(sysid, p.dirPath, addr(p.imports), addr L, true, std(sysid)[1])
  p.stylesheets[sysid] = p.imports[sysid]

newPrefixProc "parseImport":
  # Parse a new `@import x` statement.
  result = newImport()
  var m = createMaster()
  var importsOrder: seq[string]
  var L = initTicketLock()
  m.awaitAll:
    for module in p.curr.attr:
      var fpath = module
      if module.startsWith("std/"):
        # handles standard library imports
        if likely(p.imports.hasKey(module) == false):
          if likely(exists(module)):
            add result.modules, fpath
            # p.imports[module] = result
            m.spawn importer(fpath, p.dirPath, addr(p.imports), addr L, true, std(module)[1])
          else: errorWithArgs(importModuleNotFound, p.curr, [module])
        else: errorWithArgs(importDuplicateModule, p.curr, [module])
      else:
        # handle local bass/css imports
        fpath = absolutePath(fpath)
        if module.endsWith(".css"): discard
        elif not module.endsWith(".bass"):
          add fpath, ".bass"
        if fileExists(fpath):
          if likely(fpath notin result.modules):
            when compileOption("app", "console"):
              if p.cacheRefresh(fpath, p.dirPath):
                m.spawn importer(fpath, p.dirPath, addr(p.imports), addr L)
                add result.modules, fpath
              else:
                echo fpath.cached(p.dirPath)
                add result.modules, fpath
            else: discard
          else: errorWithArgs(importDuplicateModule, p.curr, [module])
        else: errorWithArgs(importModuleNotFound, p.curr, [module])
  for fpath in result.modules:
    try:
      p.stylesheets[fpath] = p.imports[fpath]
    except KeyError:
      return nil
  walk p

  # return
  # for module in p.curr.attr:
  #   var fpath = module
    # if module.startsWith("std/"):
    #   # handle imports from standard library
    #   if likely(module notin p.imports):
    #     if likely(hasModule(module)):
    #       p.imports[module] = result
    #       p.stylesheets.insert(fpath, nil) # prepare stash table
    #       inThread(importModule, true, getModule(module)[1].string)
    #       p.stylesheets.withValue(fpath):
    #         if value[] != nil:
    #           add result.modules, fpath
    #       # p.program.getStack()["count|string|string"] = Node()
    #       # echo strings().call("contains", strContainsFn).get()("This is awesome", "awesome")
    #     else: errorWithArgs(importModuleNotFound, p.curr, [module])
    #   else: errorWithArgs(importDuplicateModule, p.curr, [module])
    # else:
    # handle imports from local project
  #   fpath = absolutePath(fpath)
  #   if module.endsWith(".css"):
  #     discard
  #   else:
  #     if not fpath.endsWith(".bass"):
  #       add fpath, ".bass"
  #   if fileExists(fpath):
  #     if likely(p.imports.hasKey(fpath) == false):
  #       p.stylesheets.insert(fpath, nil) # prepare stash table
  #       p.imports[fpath] = result
  #       # tokenize & parse imported module in a separate thread
  #       when compileOption("app", "console"):
  #         if p.cacheRefresh(fpath, p.dirPath):
  #           inThread(importModule)
  #           var hasErrors: bool
  #           p.stylesheets.withValue(fpath):
  #             if value[] != nil:
  #               add result.modules, fpath
  #               if p.cacheEnabled:
  #                 cache(fpath, p.dirPath, value[])
  #             else: hasErrors = true
  #           if hasErrors:
  #             walk p
  #             return
  #         else:
  #           p.stylesheets[fpath] = fpath.cached(p.dirPath)
  #           add result.modules, fpath
  #       else:
  #         inThread(importModule)
  #         var hasErrors: bool
  #         p.stylesheets.withValue(fpath):
  #           if value[] != nil:
  #             let stylesheet: Stylesheet = value[]
  #             add result.modules, fpath
  #           else:
  #             hasErrors = true
  #         if hasErrors:
  #           walk p
  #           return
  #     else: errorWithArgs(importDuplicateModule, p.curr, [module])
  #   else: errorWithArgs(importModuleNotFound, p.curr, [module])
  # walk p

# proc parseImportFrom(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse a new `@from x import y` statement
  # discard