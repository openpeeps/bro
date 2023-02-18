# Bro aka NimSass
# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[streams, memfiles, tables, os, sequtils, strutils]
import ./tokens

## Resolve all `@include` calls inside a `view`, `layout` or `partial`.

type
  Importer* = object
    lex: Lexer
      ## An instance of `TokTok` Lexer
    rope: string
      ## The entire view containing resolved partials
    error: ErrorMessage
    currFilePath: string
      ## The absoulte file path for ``.timl`` view
    curr, next: TokenTuple
    partials: OrderedTableRef[int, tuple[indentSize: int, source: string]]
      ## An ``OrderedTable`` with ``int`` based key representing
      ## the line of the ``@import`` statement and a tuple-based value.
      ##      - ``indentSize`` field  to preserve indentation size from the view side
      ##      - ``source`` field pointing to an absolute path for ``.timl`` partial.
    sources: TableRef[string, string]
    excludes: seq[string]
    isMain: bool

  ErrorMessage* = tuple[msg, path: string, line, col: int]

const
  ImportErrorNotFound = "Cannot import \"$1\". File not found"
  ImportPartialSelf = "\"$1\" cannot import itself"
  ImportCircularError = "Circular import of $1"

proc hasError*(p: var Importer): bool =
  result = p.error.msg.len != 0

proc setError*(p: var Importer, msg: string, path: string) =
  p.error = (msg, path, p.curr.line, p.curr.col)
  # if p.sources.hasKey(path):
  #   p.error_trace = p.sources[path]

proc getError*(p: var Importer): string =
  if p.isMain:
    result = "Error ($1:$2): $3\n$4" % [$p.error.line, $p.error.col, p.error.msg, p.currFilePath]
  else:
    result = "$1\n$2" % [p.error.msg, p.currFilePath]

proc getFullCode*(p: var Importer): string =
  result = p.rope
  reset p.rope

template walk(p: var Importer, offset = 1) =
  var i = 0
  while offset != i: 
    p.curr = p.next
    p.next = p.lex.getToken()
    inc i

template loadCode(p: var Importer, indent: int) =
  var filepath = p.curr.value
  filepath =
    if filepath.splitFile.ext notin [".sass"]:
      filepath & ".sass"
    else:
      filepath
  let dirpath = parentDir(p.currFilePath)
  let path = filepath.absolutePath()
  if likely(p.sources.hasKey(path) == false):
    if not fileExists(path):
      p.setError(ImportErrorNotFound % [filepath], filepath)
    else:
      if path == p.currFilePath:
        p.setError(ImportPartialSelf % [filepath], filepath)
        break
      elif path in p.excludes:
        p.setError(ImportCircularError % [path], filepath)
        break
      var excludeCirculars = deduplicate(concat(p.excludes, @[path, p.currFilePath]))
      var resv = resolve(path, path, excludeCirculars, isMain = false)
      if resv.hasError():
        p.setError(resv.getError(), filepath)
      p.sources[path] = resv.getFullCode()
      p.partials[p.curr.line] = (indent, path)
  else:
    p.setError("Duplicate import" % [filepath], filepath)
    # p.partials[p.curr.line] = (indent, path)

template resolveChunks(p: var Importer) =
  if p.curr.kind == TkImport:
    let indent = p.curr.col
    if p.next.kind == TKString:
      walk p
      loadCode(p, indent)
    else:
      p.setError "Invalid import statement missing file path.", p.currFilePath
      break

proc resolve*(viewCode, currFilePath: string, excludes: seq[string] = @[], isMain = true): Importer =
  ## Resolve ``@include`` statements
  var mm: MemFile = memfiles.open(viewCode, mode = fmRead, mappedSize = -1)
  let slice = MemSlice(data: mm.mem, size: mm.size)
  # let slice = readFile(viewCode)
  var p = Importer(
    lex: Lexer.init(slice.data),
    partials: newOrderedTable[int, tuple[indentSize: int, source: string]](),
    sources: newTable[string, string](),
    currFilePath: currFilePath,
    excludes: excludes,
    isMain: isMain
  )

  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()

  while p.curr.kind != TK_EOF:
    if p.error.msg.len != 0: break
    p.resolveChunks()
    walk p
  
  if p.error.msg.len == 0:
    if p.partials.len == 0:
      p.rope = $slice
    else:
      var
        done: bool
        lineno, resolved = 1
        # mm = newStringStream(slice)
      for line in lines(mm):
        if not done:
          if p.partials.hasKey(lineno):
            let path = p.partials[lineno].source
            let code = p.sources[path]
            let indentSize = p.partials[lineno].indentSize
            add p.rope, indent(code, indentSize)
            add p.rope, "\n"
            if resolved == p.partials.len:
              done = true          
            inc resolved
          else:
            add p.rope, line & "\n"
        else:
          add p.rope, line & "\n"
        inc lineno
      mm.close()
  p.lex.close()
  result = p