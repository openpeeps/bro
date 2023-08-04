# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

const broCachePath = getCacheDir("bro-lang")

proc hashast(path: string): string = getMD5(path) & ".ast"

when compileOption("app", "console"):
  proc cache(path: string, stylesheet: Stylesheet) =
    discard existsOrCreateDir(broCachePath)
    writeFile(broCachePath / hashast(path), toFlatty(stylesheet).compress)

  proc cached(path: string): Stylesheet =
    let ast = readFile(broCachePath / hashast(path))
    ast.uncompress().fromFlatty(Stylesheet)

  proc cacheRefresh*(p: var Parser, path: string): bool =
    if not p.cacheEnabled: return true # returning true will ignore caching
    let cachedPath = broCachePath / hashast(path)
    if fileExists(cachedPath):
      return path.getLastModificationTime > cachedPath.getLastModificationTime
    result = true

  proc cacheExists(path: string): bool =
    fileExists(broCachePath / getMD5(path))

newPrefixProc "parseImport":
  # Parse a new `@import x` statement.
  template inThread(handle: proc(th: (string, Stylesheets)) {.thread, nimcall, gcsafe.}) =
    var thr: Thread[(string, Stylesheets)]
    createThread(thr, handle, (fpath, p.stylesheets))
    joinThread(thr) # wait for it

  result = newImport()
  for module in p.curr.attr:
    if module.startsWith("std/"):
      # handle imports from standard library
      if likely(module notin p.imports):
        p.imports[module] = newImport()
      else: errorWithArgs(importDuplicateModule, p.curr, [module])
    else:
      # handle imports from local project
      var
        handler: ImportHandler
        fpath = absolutePath(module)
      if module.endsWith(".css"):
        handler = importModuleCSS
      else:
        add fpath, ".bass"
        handler = importModule
      if fileExists(fpath):
        if likely(p.imports.hasKey(fpath) == false):
          p.stylesheets.insert(fpath, nil) # prepare stash table
          p.imports[fpath] = result
          # tokenize & parse imported module in a separate thread
          when compileOption("app", "console"):
            if p.cacheRefresh(fpath):
              inThread(handler)
              var hasErrors: bool
              p.stylesheets.withValue(fpath):
                if value[] != nil:
                  let stylesheet: Stylesheet = value[]
                  add result.modules, (fpath, stylesheet)
                  if p.cacheEnabled:
                    cache(fpath, stylesheet)
                else: hasErrors = true
              if hasErrors: return nil
            else:
              let stylesheet: Stylesheet = fpath.cached()
              add result.modules, (fpath, stylesheet)
          else:
            inThread(handler)
            var hasErrors: bool
            p.stylesheets.withValue(fpath):
              if value[] != nil:
                let stylesheet: Stylesheet = value[]
                add result.modules, (fpath, stylesheet)
              else: hasErrors = true
            if hasErrors: return nil
        else:
          errorWithArgs(importDuplicateModule, p.curr, [module])
      else:
        errorWithArgs(importModuleNotFound, p.curr, [module])
  walk p

proc parseImportFrom(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse a new `@from x import y` statement
  discard