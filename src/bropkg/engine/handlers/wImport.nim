newHandler importModule:
  if likely(c.stylesheets.len > 0):
    for path in node.modules:
      # change logger's file path during iteration
      c.logger.filePath = c.stylesheets[path].sourcePath
      for childNode in c.stylesheets[path].nodes:
        c.runHandler(childNode, scope)
    c.logger.filePath = c.program.sourcePath # back to main file

newHandler moduleInclude:
  discard