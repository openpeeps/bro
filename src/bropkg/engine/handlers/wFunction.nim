newHandler handleFunctionDef:
  #[ 
  Handles function/mixin definitions in the current scope.
  - `fn` Functions can be used to do heavy computations
  - `mix` Mixins help keep your style sheets clean and readable. A mixin
  can only return CSS properties
  ]#
  var currentScope: ScopeTable  = c.getScope(scope)
  if likely(currentScope.hasKey(node.fnIdent) == false):
    node.fnSource = c.logger.filePath
    currentScope[node.fnIdent] = node
    return
  compileErrorWithArgs(fnOverload, [node.fnName], node.meta)

newHandler fnCallVoid:
  #[
  Handles function calls with return type `void`.
  ]#
  discard runCallable()