# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

const broCachePath = getCacheDir("bro-lang")

proc cache(path: string, ast: string) =
  discard existsOrCreateDir(broCachePath)
  writeFile(broCachePath / getMD5(path) & ".ast", ast)

# proc cached(path: string): Program =
  # let x = readFile(path)
  # jsony.fromJson(x, Program)

proc cacheRefresh*(path: string): bool =
  let cachedPath = broCachePath / getMD5(path) & ".ast"
  if fileExists(cachedPath):
    return path.getLastModificationTime > cachedPath.getLastModificationTime
  result = true

proc cacheExists(path: string): bool =
  fileExists(broCachePath / getMD5(path))

newPrefixProc "parseImport":
  # Parse a new `@import x` statement.
  #
  # Stylesheet files (.css, .bass) are parsed
  # in separate threads, by creating new instances
  # of BRO Lexer and Parser. This leaves the main
  # thread as clean as possible.
  #
  # Once parsed, if there are no errors it returns the
  # produced AST back to main thread, otherwise quits the process
  # and prints the errors.
  # 
  # The AST produced from imports is cached using plain JSON
  # and stored in the current user cache directory:
  # `~/.cache/brostylesheets/proj_name`.
  # There is no need to loose precious time on serialization.
  #
  # When the original source file is updated it
  # invalidates the old AST and rebuilds from source
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
          # if cacheRefresh(fpath):
          inThread(handler)
          var hasErrors: bool
          p.stylesheets.withValue(fpath):
            if value[] != nil:
              # cache(fpath, $(jsonutils.toJson(value[])))
              # cache(fpath, jsony.toJson(value[]))
              add result.modules, (fpath, value[])
            else: hasErrors = true
          if hasErrors: return nil
          # else:
          #   echo cached()
        else: discard # todo handle duplicated imports
      else:
        errorWithArgs(importModuleNotFound, p.curr, [module])
  walk p

proc parseImportFrom(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse a new `@from x import y` statement
  discard