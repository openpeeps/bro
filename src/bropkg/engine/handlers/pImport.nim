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
  # When the original source file gets updated will
  # invalidate the old cached AST and rebuild.
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
      var fpath = absolutePath(module)
      if module.endsWith(".css"):
        # importing a `.css` file requires
        # a different parser, see `css.nim`
        if fileExists(fpath):
          if likely(p.imports.hasKey(fpath) == false):
            p.stylesheets.insert(fpath, nil) # prepare stash table
            p.imports[fpath] = result
            inThread(importModuleCSS) # create a new thread
            var hasErrors: bool
            p.stylesheets.withValue(fpath):
              if value[] != nil:
                add result.modules, (fpath, value)
              else: hasErrors = true
            if hasErrors:
              return nil
          else: discard # what to do if the same module is imported in other files too?
        else:
          errorWithArgs(importModuleNotFound, p.curr, [module])
      else:
        add fpath, ".bass"
        if fileExists(fpath):
          if likely(p.imports.hasKey(fpath) == false):
            p.stylesheets.insert(fpath, nil) # prepare stash table
            p.imports[fpath] = result
            inThread(importModule) # create a new thread
            p.stylesheets.withValue(fpath):
              add result.modules, (fpath, value)
          else: discard # what to do if the same module is imported in other files too?
        else:
          errorWithArgs(importModuleNotFound, p.curr, [module])
  walk p

proc parseImportFrom(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse a new `@from x import y` statement
  discard