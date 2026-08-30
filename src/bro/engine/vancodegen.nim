# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/os
import pkg/voodoo/extensibles

block extendAST:
  extendEnum NodeKind:
    nkClassSelector
    nkIdSelector
    nkPseudoSelector
    nkElementSelector
    nkUnit
    nkExprList
    nkProperty  # Represents a CSS property (e.g., color: red)
    nkValue     # Represents a CSS value (e.g., 16px, red)
    nkAtRule    # Represents a CSS at-rule (e.g., @media, @supports)
    nkCommaList # Represents comma-separated CSS values (e.g., 13, 110, 253)
    nkMixinDef  # Represents a mixin definition (reusable declaration block)
    nkCssComment # Preserved doc-block comment (/*! ... */ or /** ... */)
    nkCase
    nkOfBranch

block extendSym:
  extendEnum TypeKind:
    ttyColor
    ttyLength
    ttyNumber
    ttyKeyword
    ttyAngle
    ttyTime
    ttyUrl
    ttyCssString
    ttyResolution
    ttyFlex
block extendCodeGen:
  extendModule "vancode" / "interpreter" / "codegen.nim":
    import pkg/openparser/css as cssmod

    var nestingParent: string = "" ## Sass-style nesting: parent selector context for & substitution
    var mixinTable = initTable[string, Node]() ## registered mixin definitions (name -> nkMixinDef)
    var rawPropMode = false ## when true, properties emit as raw text (for if/for inside rules)
    ## Optional hook for reporting non-fatal codegen warnings; when unset,
    ## warnings go to stderr with a `[warn]` prefix. The CLI layer installs
    ## a handler that routes messages through kapsis `displayWarning`.
    var warnHandler*: proc(msg: string) {.gcsafe.}

    proc codegenWarn(file: string, ln, col: int, msg: string) =
      let full = file & ":" & $ln & ":" & $col & " " & msg
      if warnHandler != nil:
        warnHandler(full)
      else:
        stderr.write("[warn] " & full & "\n")

    let cssData = cssmod.loadCssData()

    proc parseCssValues(raw: string): seq[cssmod.CssValue] =
      let fakeCss = "*{x:" & raw & "}"
      let style = cssmod.parseCss(fakeCss)
      if style.nodes.len > 0 and style.nodes[0].kind == cssmod.cssRuleSet:
        if style.nodes[0].declarations.len > 0:
          result = style.nodes[0].declarations[0].valueComponents

    proc cssValidateProp(propName: string, rawValue: var string): string =
      let vals = parseCssValues(rawValue)
      var res = cssmod.validate(cssData, propName, vals)
      if not res.valid:
        # Try auto-appending px for bare numbers like "100" -> "100px"
        if rawValue.len > 0 and rawValue[0] in {'0'..'9', '-'} and not rawValue.contains({'a'..'z', 'A'..'Z', '%'}):
          let pxValue = rawValue & "px"
          let pxVals = parseCssValues(pxValue)
          let pxRes = cssmod.validate(cssData, propName, pxVals)
          if pxRes.valid:
            rawValue = pxValue
            res = pxRes
          else:
            res = pxRes
        if not res.valid:
          var expected = ""
          if cssData.properties.hasKey(propName):
            expected = cssData.properties[propName].syntax
          var msg = propName & ": got '" & rawValue & "'"
          if expected.len > 0:
            msg &= ", expected " & expected
          raise newException(ValueError, msg)
      let syn = cssmod.getPropertySyntax(cssData, propName)
      if syn == nil: return "keyword"
      case syn.kind
      of skType: result = syn.cssType
      else: result = "keyword"

    proc cssGetPropertySyntax(propName: string): cssmod.SyntaxNode =
      cssmod.getPropertySyntax(cssData, propName)

    proc cssTypeToKind(cssType: string): TypeKind =
      case cssType
      of "color": ttyColor
      of "length": ttyLength
      of "number", "integer": ttyNumber
      of "angle": ttyAngle
      of "time": ttyTime
      of "url": ttyUrl
      of "resolution": ttyResolution
      of "flex": ttyFlex
      of "string": ttyCssString
      else: ttyKeyword

    proc cssFloatStr(f: float): string =
      ## Render a float for CSS output — strips a trailing ".0" so integral
      ## values emit as "1000" instead of "1000.0" (e.g. scientific notation).
      result = $f
      if result.endsWith(".0"):
        result.setLen(result.len - 2)

    proc nodeToCssString(node: Node): string

    proc nodeToCssString(node: Node): string =
      case node.kind
      of nkIdent: result = node.ident
      of nkInt: result = $node.intVal
      of nkFloat: result = cssFloatStr(node.floatVal)
      of nkString:
        if node.stringVal.len > 0 and node.stringVal[0] == '#':
          result = node.stringVal # hex color literal, no quotes
        else:
          # Re-escape double quotes for valid CSS string output
          result = "\"" & node.stringVal.replace("\"", "\\\"") & "\""
      of nkUnit:
        result = if node[0].kind == nkInt: $node[0].intVal else: cssFloatStr(node[0].floatVal)
        result &= node[1].ident
      of nkExprList:
        var parts: seq[string]
        for child in node.children:
          parts.add(nodeToCssString(child))
        result = parts.join(" ")
      of nkCommaList:
        var cparts: seq[string]
        for child in node.children:
          cparts.add(nodeToCssString(child))
        result = cparts.join(", ")
      of nkCall:
        if node.children.len > 0 and node[0].kind == nkIdent:
          result = node[0].ident & "("
          var args: seq[string]
          for i in 1..<node.children.len:
            args.add(nodeToCssString(node[i]))
          result &= args.join(",") & ")"
      of nkInfix:
        if node.children.len >= 3:
          result = nodeToCssString(node[1]) & " " & nodeToCssString(node[0]) & " " & nodeToCssString(node[2])
      of nkPostfix:
        if node.children.len >= 2:
          result = nodeToCssString(node[1]) & " !" & node[0].ident
      else: result = ""

    proc splitSelector(text: string): seq[string] =
      ## Split a comma-separated selector text into individual selectors.
      for part in text.split(','):
        let s = part.strip()
        if s.len > 0:
          result.add(s)

    proc selectorText(node: Node): string =
      ## Extract the raw selector text from a selector node.
      case node[0].kind
      of nkIdent: result = node[0].ident
      of nkBracket:
        var parts: seq[string]
        for id in node[0].children:
          if id.kind == nkIdent:
            parts.add(id.ident)
        result = parts.join(",")
      else: result = ""

    proc applyParent(childText, parentText: string): seq[string] =
      ## Sass-style selector combination.
      ## If child contains `&`, replace `&` with parent (compound, no space).
      ## If child doesn't contain `&`, prepend parent with space (descendant).
      var childParts = splitSelector(childText)
      var parentParts = splitSelector(parentText)
      result = @[]
      for parent in parentParts:
        for child in childParts:
          if '&' in child:
            result.add(child.replace("&", parent))
          else:
            result.add(parent & " " & child)

    proc expandValue(n: Node, pm: Table[string, Node]): Node =
      ## Recursively substitute mixin parameters (`$name`) in an expression tree.
      case n.kind
      of nkIdent:
        if n.ident in pm: pm[n.ident] else: n
      of nkExprList, nkCommaList, nkInfix, nkPostfix, nkCall, nkBracket:
        let r = ast.newNode(n.kind)
        for c in n.children:
          r.add(expandValue(c, pm))
        r.ln = n.ln; r.col = n.col
        r
      else: n # leaves (nkInt, nkFloat, nkString, nkUnit...) pass through

    proc substStmt(n: Node, pm: Table[string, Node]): Node =
      ## Recursively substitute mixin parameters within a statement node.
      case n.kind
      of nkColon:
        # property: key stays, value substitutes. Keep source position so
        # sourcemaps point at the mixin definition (Sass behavior).
        let r = ast.newTree(nkColon, n[0], expandValue(n[1], pm))
        r.ln = n.ln; r.col = n.col
        r
      of nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector:
        var blk = ast.newNode(nkBlock)
        for c in n[3].children:
          blk.add(substStmt(c, pm))
        let r = ast.newTree(n.kind, n[0], n[1], n[2], blk)
        r.ln = n.ln; r.col = n.col
        r
      of nkAtRule:
        var blk = ast.newNode(nkBlock)
        for c in n[2].children:
          blk.add(substStmt(c, pm))
        let r = ast.newTree(nkAtRule, n[0], n[1], blk)
        r.ln = n.ln; r.col = n.col
        r
      of nkIf:
        let r = ast.newNode(nkIf)
        var i = 0
        while i < n.len:
          if i mod 2 == 0 and (i + 1 < n.len or n.len mod 2 == 0):
            r.add(expandValue(n[i], pm)) # condition
          else:
            var blk = ast.newNode(nkBlock)
            for c in n[i].children:
              blk.add(substStmt(c, pm))
            r.add(blk)
          inc i
        r.ln = n.ln; r.col = n.col
        r
      of nkWhile:
        var blk = ast.newNode(nkBlock)
        for c in n[1].children:
          blk.add(substStmt(c, pm))
        let r = ast.newTree(nkWhile, expandValue(n[0], pm), blk)
        r.ln = n.ln; r.col = n.col
        r
      of nkFor:
        var blk = ast.newNode(nkBlock)
        for c in n[2].children:
          blk.add(substStmt(c, pm))
        let r = ast.newTree(nkFor, n[0], expandValue(n[1], pm), blk)
        r.ln = n.ln; r.col = n.col
        r
      else: n

    proc paramNames(m: Node): seq[string] =
      ## Extract parameter names from a mixin's nkFormalParams node.
      ## Note: parseIdentDefs merges comma-separated params into a single
      ## nkIdentDefs whose leading children are the identifiers.
      let fp = m[1]
      for i in 1 ..< fp.len:
        let pd = fp[i]
        if pd.kind == nkIdentDefs and pd.len >= 3:
          for j in 0 ..< pd.len - 2:
            if pd[j].kind == nkIdent:
              result.add(pd[j].ident)
        elif pd.kind == nkIdent:
          result.add(pd.ident)

    proc paramDefault(m: Node, name: string): Node =
      ## Return the default value node for a parameter, or nil.
      let fp = m[1]
      for i in 1 ..< fp.len:
        let pd = fp[i]
        if pd.kind == nkIdentDefs and pd.len >= 3:
          var inGroup = false
          for j in 0 ..< pd.len - 2:
            if pd[j].kind == nkIdent and pd[j].ident == name:
              inGroup = true
          if inGroup:
            let dv = pd[pd.len - 1]
            if dv.kind != nkEmpty:
              return dv
      return nil

    proc paramKey(name: string): string =
      ## Body references use the `$name` form; signature params are bare
      ## (`mixin btn(color: color)`). Normalize either spelling to `$name`.
      if name.len > 0 and name[0] == '$': name else: "$" & name

    proc expandMixin(call: Node): seq[Node] =
      ## Expand a mixin call into spliced body statements with args substituted.
      let callee = call[0].ident
      if not mixinTable.hasKey(callee):
        call.error("unknown mixin '" & callee & "'")
      let m = mixinTable[callee]
      let pnames = paramNames(m)
      var pm = initTable[string, Node]()
      # set of normalized parameter keys for membership checks
      var pkeys: seq[string]
      for pn in pnames:
        pkeys.add(paramKey(pn))
      var posIdx = 0
      for i in 1 ..< call.len:
        let a = call[i]
        if a.kind == nkColon and a[0].kind == nkIdent and paramKey(a[0].ident) in pkeys:
          pm[paramKey(a[0].ident)] = a[1] # named argument ($h = 5px or h = 5px)
        else:
          if posIdx >= pnames.len:
            call.error("too many arguments for mixin '" & callee & "'")
          pm[paramKey(pnames[posIdx])] = a
          inc posIdx
      for pn in pnames:
        if paramKey(pn) notin pm:
          let dv = paramDefault(m, pn)
          if dv != nil:
            pm[paramKey(pn)] = dv
          else:
            call.error("missing argument '" & pn & "' for mixin '" & callee & "'")
      for child in m[2].children:
        result.add(substStmt(child, pm))

    proc genSelector*(node: Node): Sym {.codegen, discardable.} =
      ## Generate bytecode for a CSS selector (class, id, or pseudo)
      assert node.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector}, "Expected selector node"

      let selectorType =
        case node.kind
        of nkClassSelector: 0'u16
        of nkIdSelector: 1'u16
        of nkPseudoSelector: 2'u16
        of nkElementSelector: 3'u16
        else: 0'u16

      # Extract selector name from AST
      var selectorName: string
      case node[0].kind
      of nkIdent:
        selectorName = node[0].ident
      of nkBracket:
        for i, id in node[0].children:
          if id.kind == nkIdent:
            if i > 0: selectorName.add(",")
            selectorName.add(id.ident)
      else: node[0].error("Invalid selector name")

      # Compute full selector text (with parent nesting context via & substitution)
      let prefix =
        case selectorType
        of 0: "."
        of 1: "#"
        of 2: ":"
        else: ""
      let fullText = if nestingParent.len > 0:
        # include the kind prefix (.foo / #foo / :foo) so spliced mixin
        # selectors (nkClassSelector etc.) keep their sigil when combined
        applyParent(prefix & selectorName, nestingParent).join(", ")
      else:
        prefix & selectorName
      let hasParent = nestingParent.len > 0

      # Phase 0: expand mixin calls among body children
      var bodyChildren: seq[Node]
      for child in node[3].children:
        if child.kind == nkCall and child.len > 0 and child[0].kind == nkIdent:
          if mixinTable.hasKey(child[0].ident):
            for spilled in expandMixin(child):
              bodyChildren.add(spilled)
          else:
            # Not a known mixin — keep as-is (may be handled elsewhere);
            # warn so silent drops are visible.
            codegenWarn(gen.chunk.file, child.ln, child.col,
              "unknown mixin '" & child[0].ident & "' (mixin must be defined before use)")
            bodyChildren.add(child)
        else:
          bodyChildren.add(child)

      # Phase 0b: desugar nkCase → nkIf chains for VM codegen
      proc desugarCase(n: Node): Node =
        ## case X of 1: a of 2: b else: c → if X == 1: a elif X == 2: b else: c
        if n.kind != nkCase: return n
        let subject = n[0]
        var ifChildren: seq[Node]
        var i = 1
        while i < n.len:
          let branch = n[i]
          if branch.kind == nkBlock:
            # else branch
            ifChildren.add(branch)
            break
          elif branch.kind == nkOfBranch:
            let cond = ast.newInfix(ast.newIdent("=="),
              subject, branch[0])
            let blk = branch[1]
            ifChildren.add(cond)
            ifChildren.add(blk)
          inc i
        result = ast.newTree(nkIf, ifChildren)
        result.ln = n.ln; result.col = n.col
      for idx in 0 ..< bodyChildren.len:
        bodyChildren[idx] = desugarCase(bodyChildren[idx])

      # Phase 1: scan body to separate properties from nested children
      var
        nestedStmts: seq[Node]
        pendingComments: seq[Node]
        propCount = 0
      for child in bodyChildren:
        case child.kind
        of nkCssComment:
          pendingComments.add(child) # emitted before this rule's block
        of nkColon:
          inc propCount
        else:
          nestedStmts.add(child)

      # Detect nested selectors (Sass-style nesting)
      var hasNestedSelectors = false
      var hasNestedAtRule = false
      var hasControlFlow = false
      var hasDuplicate = false
      for s in nestedStmts:
        case s.kind
        of nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector:
          hasNestedSelectors = true
        of nkAtRule:
          hasNestedAtRule = true
        of nkIf, nkWhile, nkFor, nkCase:
          hasControlFlow = true
        else: discard
      # Check for duplicate property keys in this block
      var seenKeys: seq[string]
      for child in bodyChildren:
        if child.kind == nkColon:
          let k = if child[0].kind == nkIdent: child[0].ident
                  elif child[0].kind == nkString: child[0].stringVal
                  else: ""
          if k.len > 0 and k in seenKeys:
            hasDuplicate = true
          seenKeys.add(k)

      result = newType(ttyObject, name = node[0], impl = node)

      # Doc-block banners precede this rule in every emission path
      for cnode in pendingComments:
        gen.genStmt(cnode)

      # ── NESTING PATH: Sass-style ──────────────────────────────
      if hasNestedSelectors:
        # Emit parent properties as raw text (no stack pollution)
        if propCount > 0:
          gen.chunk.emit(opcPushS)
          gen.chunk.emit(gen.chunk.getString(fullText & "{"))
          gen.chunk.emit(opcEmitRaw)
          gen.chunk.emit(uint16(node.ln))
          gen.chunk.emit(uint16(node.col))
          # find last property child for trailing-; optimization
          var lastPropIdx = -1
          for ci, child in bodyChildren:
            if child.kind == nkColon:
              lastPropIdx = ci
          for ci, child in bodyChildren:
            if child.kind == nkColon:
              let key = child[0].ident
              let val = nodeToCssString(child[1])
              if val.len > 0:
                let isVarRef = child[1].kind == nkIdent and child[1].ident.len > 0 and child[1].ident[0] == '$'
                if not isVarRef and child[1].kind in {nkIdent, nkInt, nkFloat, nkString, nkUnit, nkExprList, nkCommaList, nkCall, nkPostfix}:
                  var validateCss = if child[1].kind == nkPostfix: nodeToCssString(child[1][1]) else: val
                  try:
                    discard cssValidateProp(key, validateCss)
                  except CatchableError as e:
                    if key in ["box-shadow", "grid-template-columns", "content", "margin", "inherits"]:
                      discard
                    else:
                      child.error(e.msg)
                gen.chunk.emit(opcPushS)
                let isLast = ci == lastPropIdx
                let css = if isLast: key & ":" & val
                          else: key & ":" & val & ";"
                gen.chunk.emit(gen.chunk.getString(css))
                gen.chunk.emit(opcEmitRaw)
                gen.chunk.emit(uint16(child.ln))
                gen.chunk.emit(uint16(child.col))
          gen.chunk.emit(opcPushS)
          gen.chunk.emit(gen.chunk.getString("}"))
          gen.chunk.emit(opcEmitRaw)
          gen.chunk.emit(uint16(0xFFFF))
          gen.chunk.emit(uint16(0))
        # Flatten nested selectors with this selector as parent context
        let savedParent = nestingParent
        nestingParent = fullText
        for stmt in nestedStmts:
          case stmt.kind
          of nkIf, nkWhile, nkFor, nkCase:
            rawPropMode = true
            gen.genStmt(stmt)
            rawPropMode = false
          else:
            gen.genStmt(stmt)
        nestingParent = savedParent
        return

      # ── RAW MODE: at-rules, duplicates, or control flow ───────
      # Control flow needs raw emission so VM-time conditions can decide
      # which declarations appear inside the rule block.
      if hasNestedAtRule or hasDuplicate or hasControlFlow:
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString(fullText & "{"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))
        # Declarations & control flow in source order
        var lastPropIdx = -1
        for ci, child in bodyChildren:
          if child.kind == nkColon:
            lastPropIdx = ci
        for ci, child in bodyChildren:
          case child.kind
          of nkColon:
            let key = child[0].ident
            let val = nodeToCssString(child[1])
            if val.len > 0:
              let isVarRef = child[1].kind == nkIdent and child[1].ident.len > 0 and child[1].ident[0] == '$'
              if not isVarRef and child[1].kind in {nkIdent, nkInt, nkFloat, nkString, nkUnit, nkExprList, nkCommaList, nkCall, nkPostfix}:
                var validateCss = if child[1].kind == nkPostfix: nodeToCssString(child[1][1]) else: val
                try:
                  discard cssValidateProp(key, validateCss)
                except CatchableError as e:
                  if key in ["box-shadow", "grid-template-columns", "content", "margin", "inherits"]:
                    discard
                  else:
                    child.error(e.msg)
              gen.chunk.emit(opcPushS)
              let isLast = ci == lastPropIdx
              let css = if isLast: key & ":" & val
                        else: key & ":" & val & ";"
              gen.chunk.emit(gen.chunk.getString(css))
              gen.chunk.emit(opcEmitRaw)
              gen.chunk.emit(uint16(child.ln))
              gen.chunk.emit(uint16(child.col))
          of nkIf, nkWhile, nkFor, nkCase:
            rawPropMode = true
            gen.genStmt(child)
            rawPropMode = false
          else: discard
        # At-rules nest INSIDE the rule block
        for stmt in nestedStmts:
          if stmt.kind == nkAtRule:
            gen.genStmt(stmt)
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("}"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(0xFFFF))
        gen.chunk.emit(uint16(0))
        # Spliced nested selectors flatten with this rule as parent
        let savedParent = nestingParent
        nestingParent = fullText
        for stmt in nestedStmts:
          if stmt.kind != nkAtRule:
            gen.genStmt(stmt)
        nestingParent = savedParent
        return

      # ── NORMAL PATH: flat selector ────────────────────────────
      gen.chunk.emit(opcPushSelector)
      if hasParent:
        # Nested child: fullText includes parent context, use element type (no VM prefix)
        gen.chunk.emit(gen.chunk.getString(fullText))
        gen.chunk.emit(3'u16)
      else:
        gen.chunk.emit(gen.chunk.getString(selectorName))
        gen.chunk.emit(selectorType)

      var keyIdxes: seq[uint16]
      for child in bodyChildren:
        if child.kind != nkColon:
          continue
        let prop = child
        let key =
          if prop[0].kind == nkIdent: prop[0].ident
          elif prop[0].kind == nkString: prop[0].stringVal
          else: prop[0].error("Invalid property key: " & $prop[0].kind); ""

        if result.objectFields.hasKey(key):
          hasDuplicate = true
        let isVarRef = prop[1].kind == nkIdent and prop[1].ident.len > 0 and prop[1].ident[0] == '$'

        # Validate CSS property value for literal values
        if not isVarRef and prop[1].kind in {nkIdent, nkInt, nkFloat, nkString, nkUnit, nkExprList, nkCommaList, nkCall, nkPostfix}:
          var rawCss = nodeToCssString(prop[1])
          if rawCss.len > 0:
            var validateCss =
              if prop[1].kind == nkPostfix: nodeToCssString(prop[1][1])
              else: rawCss
            try:
              discard cssValidateProp(key, validateCss)
            except CatchableError as e:
              if key in ["box-shadow", "grid-template-columns", "content", "margin", "inherits"]:
                discard
              else:
                prop.error(e.msg)
            let cssType = cssGetPropertySyntax(key)
            let expectedKind =
              if cssType != nil and cssType.kind == skType:
                cssTypeToKind(cssType.cssType)
              else:
                ttyKeyword
            keyIdxes.add(gen.chunk.getString(key))
            gen.chunk.emit(opcPushS)
            gen.chunk.emit(gen.chunk.getString(rawCss))
            let valTy = newType(expectedKind, name = prop[1])
            result.objectFields[key] = (
              id: result.objectFields.len,
              name: prop[0],
              ty: valTy,
              implVal: valTy
            )
            continue

        keyIdxes.add(gen.chunk.getString(key))
        let valTy =
          if isVarRef:
            gen.genExpr(prop[1])
          else:
            case prop[1].kind
            of nkIdent:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(prop[1].ident))
              newType(ttyString, name = prop[1])
            of nkInt:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString($prop[1].intVal))
              newType(ttyString, name = prop[1])
            of nkFloat:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(cssFloatStr(prop[1].floatVal)))
              newType(ttyString, name = prop[1])
            of nkString:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(prop[1].stringVal))
              newType(ttyString, name = prop[1])
            of nkCommaList, nkExprList:
              # multi-segment CSS values (`a, b, c`) render as verbatim text
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(nodeToCssString(prop[1])))
              newType(ttyString, name = prop[1])
            else:
              gen.genExpr(prop[1])
        result.objectFields[key] = (
          id: result.objectFields.len,
          name: prop[0],
          ty: valTy,
          implVal: valTy
        )

      gen.chunk.emit(opcConstrObj)
      gen.chunk.emit(uint16(result.objectFields.len))
      for kix in keyIdxes:
        gen.chunk.emit(kix)
      gen.chunk.emit(opcEmitCSS)
      gen.chunk.emit(uint16(propCount + 1))
      gen.chunk.emit(uint16(node.ln))
      gen.chunk.emit(uint16(node.col))
      for child in bodyChildren:
        if child.kind == nkColon:
          gen.chunk.emit(uint16(child.ln))
          gen.chunk.emit(uint16(child.col))

    proc genCssClass*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS class selector
      result = gen.genSelector(node)

    proc genPseudoSelector*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS pseudo-selector
      result = gen.genSelector(node)

    proc genCssProperty*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS property
      assert node.kind == nkColon, "Expected nkColon node"

      if rawPropMode:
        # Inside control flow (if/for/while) within a rule body: emit the
        # declaration as raw text so VM-time conditions can include it.
        let key = node[0].ident
        let v = node[1]
        let isVarRef = v.kind == nkIdent and v.ident.len > 0 and v.ident[0] == '$'
        if isVarRef or v.kind notin {nkIdent, nkInt, nkFloat, nkString, nkUnit, nkExprList, nkCommaList, nkCall, nkPostfix}:
          # VM-evaluated value: `key:` + value + `;` as three raw emissions
          gen.chunk.emit(opcPushS)
          gen.chunk.emit(gen.chunk.getString(key & ":"))
          gen.chunk.emit(opcEmitRaw)
          gen.chunk.emit(uint16(node.ln))
          gen.chunk.emit(uint16(node.col))
          discard gen.genExpr(v)
          gen.chunk.emit(opcEmitRaw)
          gen.chunk.emit(uint16(0xFFFF))
          gen.chunk.emit(uint16(0))
          gen.chunk.emit(opcPushS)
          gen.chunk.emit(gen.chunk.getString(";"))
          gen.chunk.emit(opcEmitRaw)
          gen.chunk.emit(uint16(0xFFFF))
          gen.chunk.emit(uint16(0))
        else:
          let val = nodeToCssString(v)
          if key in ["box-shadow", "grid-template-columns", "content"]:
            discard
          else:
            var validateCss = if v.kind == nkPostfix: nodeToCssString(v[1]) else: val
            try:
              discard cssValidateProp(key, validateCss)
            except CatchableError as e:
              if key in ["margin", "inherits"]:
                discard
              else:
                node.error(e.msg)
          gen.chunk.emit(opcPushS)
          gen.chunk.emit(gen.chunk.getString(key & ":" & val & ";"))
          gen.chunk.emit(opcEmitRaw)
          gen.chunk.emit(uint16(node.ln))
          gen.chunk.emit(uint16(node.col))
        return nil

      # Push the property name
      gen.chunk.emit(opcPushProperty)
      gen.chunk.emit(gen.chunk.getString(node[0].ident))

      # Push the property value
      discard gen.genExpr(node[1])

    proc genUnit*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS unit (e.g., 16px)
      assert node.kind == nkUnit, "Expected nkUnit node"

      # Push the unit value as a string (e.g., "16px")
      var size: string
      case node[0].kind
        of nkInt:
          size = $(node[0].intVal)
        of nkFloat:
          size = cssFloatStr(node[0].floatVal)
        else: node[0].error("Invalid unit value")

      let unitStr = size & node[1].ident
      gen.chunk.emit(opcPushValue)
      gen.chunk.emit(gen.chunk.getString(unitStr))

    proc genExprList*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a list of expressions (e.g., multiple properties)
      assert node.kind == nkExprList, "Expected nkExprList node"
      var parts: seq[string]
      for child in node.children:
        case child.kind
        of nkIdent: parts.add(child.ident)
        of nkInt: parts.add($child.intVal)
        of nkFloat: parts.add(cssFloatStr(child.floatVal))
        of nkString: parts.add(child.stringVal)
        of nkUnit:
          var v = if child[0].kind == nkInt: $child[0].intVal else: cssFloatStr(child[0].floatVal)
          parts.add(v & child[1].ident)
        else: parts.add("<value>")
      let combined = parts.join(" ")
      gen.chunk.emit(opcPushS)
      gen.chunk.emit(gen.chunk.getString(combined))
      result = newType(ttyString, name = node)

    proc genAtRule*(node: Node): Sym {.codegen.} =
      assert node.kind == nkAtRule, "Expected nkAtRule node"
      let name = node[0].ident
      var prelude = ""
      if node[1].kind == nkString and node[1].stringVal.len > 0:
        prelude = " " & node[1].stringVal
      if node[2].children.len > 0:
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("@" & name & prelude & "{"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))
        var lastPropIdx = -1
        for ci, child in node[2].children:
          if child.kind == nkColon:
            lastPropIdx = ci
        for ci, child in node[2].children:
          if child.kind == nkColon:
            let key = child[0].ident
            let val = nodeToCssString(child[1])
            let isVarRef = child[1].kind == nkIdent and child[1].ident.len > 0 and child[1].ident[0] == '$'
            if not isVarRef and child[1].kind in {nkIdent, nkInt, nkFloat, nkString, nkUnit, nkExprList, nkCommaList, nkCall, nkPostfix}:
              var validateCss = if child[1].kind == nkPostfix: nodeToCssString(child[1][1]) else: val
              try:
                discard cssValidateProp(key, validateCss)
              except CatchableError as e:
                if key in ["box-shadow", "grid-template-columns", "content", "margin", "inherits"]:
                  discard
                else:
                  child.error(e.msg)
            gen.chunk.emit(opcPushS)
            let isLast = ci == lastPropIdx
            let css = if isLast: key & ":" & val
                      else: key & ":" & val & ";"
            gen.chunk.emit(gen.chunk.getString(css))
            gen.chunk.emit(opcEmitRaw)
            gen.chunk.emit(uint16(child.ln))
            gen.chunk.emit(uint16(child.col))
          else:
            gen.genStmt(child)
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("}"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(0xFFFF)) # no source mapping for closing brace
        gen.chunk.emit(uint16(0))
      else:
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("@" & name & prelude & ";"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))

  extendCaseStmt "codeGenExpr":
    case node.kind
    of nkUnit: discard gen.genUnit(node)
    of nkExprList: discard gen.genExprList(node)

  extendCaseStmt "codeGenStmt":
    case node.kind
    of nkClassSelector:
      discard gen.genCssClass(node)
    of nkPseudoSelector:
      discard gen.genPseudoSelector(node)
    of nkIdSelector:
      gen.genSelector(node)
    of nkElementSelector:
      gen.genSelector(node)
    of nkUnit:
      discard gen.genUnit(node)
    of nkExprList:
      discard
    of nkColon:
      discard gen.genCssProperty(node)
    of nkAtRule:
      discard gen.genAtRule(node)
    of nkMixinDef:
      # Register the mixin for later expansion; definitions emit no CSS.
      if node[0].kind == nkIdent:
        mixinTable[node[0].ident] = node
    of nkCssComment:
      # Preserve doc-block banners (/*! */ and /** */) — the parser stores
      # the fully-wrapped CSS text, so emission is a verbatim raw chunk.
      # A trailing newline keeps the following rule readable in minified mode.
      if node.len > 0 and node[0].kind == nkString:
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString(node[0].stringVal & "\n"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(0xFFFF))
        gen.chunk.emit(uint16(0))
    of nkCase:
      # Desugar case/of → if/elif/else and re-dispatch
      let subject = node[0]
      var ifChildren: seq[Node]
      var i = 1
      while i < node.len:
        let branch = node[i]
        if branch.kind == nkBlock:
          ifChildren.add(branch)
          break
        elif branch.kind == nkOfBranch:
          let cond = ast.newInfix(ast.newIdent("=="), subject, branch[0])
          ifChildren.add(cond)
          ifChildren.add(branch[1])
        inc i
      gen.genStmt(ast.newTree(nkIf, ifChildren))

block extendVM:
  extendEnum Opcode:
    opcPushSelector  # Push a class selector onto the stack
    opcPushProperty       # Push a CSS property
    opcPushValue          # Push a CSS value
    opcEmitCSS            # Emit the final CSS
    opcEmitRaw            # Emit a raw string directly to the output

  injectSnippet "VanCodeVMBeforeMainLoop":
    # a Voodoo injected snippet to initialize the `result` variable and the
    # source map segment accumulator (read back by the CLI after interpret)
    result = initValue("")
    vm.globals["__bro_sourcemap_segments"] = initValue("")
    # pretty-printing state lives in vm.globals because extended case
    # branches cannot capture snippet locals. Depth tracks rule nesting so
    # raw and structured emissions interleave correctly.
    if not vm.globals.hasKey("__bro_pretty"):
      vm.globals["__bro_pretty"] = initValue(false)
    vm.globals["__bro_depth"] = initValue(0'i64)
    # Pretty-layout cursor state (avoids scanning the output buffer):
    # __bro_atline — cursor sits at a logical line start (a '\n' is already
    #                in place, possibly followed by pending auto-indent);
    # __bro_indw   — width of the pending auto-indent written on this line,
    #                so closing braces can truncate it without inspection.
    vm.globals["__bro_atline"] = initValue(true)
    vm.globals["__bro_indw"] = initValue(0'i64)

  extendCaseStmt "vmParseChunkCase":
    case oc:
    of opcPushSelector:
      # selector op has two args: string id, kind (uint16)
      let sid = readArg[uint16](pc)
      let kind = readArg[uint16](pc)
      addOp(oc, sid.int64, kind.int64, akString)
    of opcPushProperty, opcPushValue:
      let sid = readArg[uint16](pc)
      addOp(oc, sid.int64, 0, akString)
    of opcEmitRaw:
      # carries a source position (line, col) for source maps; 0xFFFF = no mapping
      let line = readArg[uint16](pc)
      let col = readArg[uint16](pc)
      addOp(oc, line.int64, col.int64, akInt)
    of opcEmitCSS:
      # carries a count followed by that many (line, col) position pairs,
      # stored in strKeys. First pair is the selector, rest are its properties.
      let cnt = readArg[uint16](pc).int
      addOp(oc, cnt.int64, 0, akInt)
      var poses: seq[uint16]
      for i in 0 ..< cnt:
        poses.add(readArg[uint16](pc))
        poses.add(readArg[uint16](pc))
      strKeys[^1] = poses

  extendCaseStmt "vmInterpretCase":
    case oc:
    of opcPushSelector:
      let className = co.getArg1Str(pcIdx, currentChunk)
      let kind = co.arg2[pcIdx].int
      stack.push(initValue(kind))
      stack.push(initValue(className))
    of opcPushValue:
      let valueStr = co.getArg1Str(pcIdx, currentChunk)
      stack.push(initValue(valueStr))
    of opcEmitRaw:
      let sl = co.getArg1Int(pcIdx)
      let sc = co.arg2[pcIdx].int
      if sl != 0xFFFF: # not a "no mapping" sentinel
        vm.globals["__bro_sourcemap_segments"].stringVal[].add(
          $result.stringVal[].len & "\x03" & $sl & "\x03" & $sc & "\x03" & currentChunk.file & "\x02")
      # Type-tolerant pop: raw emissions may carry VM-evaluated values
      # (ints, floats, bools) from control-flow property values.
      let sv = stack.pop()
      let rawStr =
        case sv.typeId
        of tyString: sv.stringVal[]
        of tyInt: $sv.intVal
        of tyFloat:
          var fs = $sv.floatVal
          let fn = fs.len
          if fn > 2 and fs[fn - 2] == '.' and fs[fn - 1] == '0':
            fs.setLen(fn - 2)
          fs
        of tyBool: $sv.boolVal
        else: ""
      let prettyNow = vm.globals["__bro_pretty"].boolVal
      let depthNow = vm.globals["__bro_depth"].intVal.int
      # Strip trailing ';' before '}' — O(1) single-char check
      if rawStr == "}" and result.stringVal[].len > 0 and result.stringVal[^1] == ';':
        result.stringVal[].setLen(result.stringVal[].len - 1)
      if not prettyNow or rawStr.len == 0:
        result.stringVal[].add(rawStr)
      elif rawStr == "}":
        # closing brace: drop pending auto-indent (its leading '\n' survives),
        # or open a fresh line when the previous chunk left none
        let indW = vm.globals["__bro_indw"].intVal.int
        if indW > 0:
          result.stringVal[].setLen(result.stringVal[].len - indW)
        else:
          result.stringVal[].add('\n')
        vm.globals["__bro_depth"] = initValue((depthNow - 1).int64)
        for _ in 1 .. (depthNow - 1) * 2:
          result.stringVal[].add(' ')
        result.stringVal[].add(rawStr)
        result.stringVal[].add('\n')
        for _ in 1 .. (depthNow - 1) * 2:
          result.stringVal[].add(' ')
        vm.globals["__bro_indw"] = initValue(((depthNow - 1) * 2).int64)
        vm.globals["__bro_atline"] = initValue(true)
      elif rawStr[^1] == '{':
        # opener: header line, then descend
        if not vm.globals["__bro_atline"].boolVal:
          result.stringVal[].add('\n')
          for _ in 1 .. depthNow * 2:
            result.stringVal[].add(' ')
          vm.globals["__bro_indw"] = initValue((depthNow * 2).int64)
        result.stringVal[].add(rawStr)
        vm.globals["__bro_indw"] = initValue(0'i64) # header content landed
        vm.globals["__bro_depth"] = initValue((depthNow + 1).int64)
        result.stringVal[].add('\n')
        for _ in 1 .. (depthNow + 1) * 2:
          result.stringVal[].add(' ')
        vm.globals["__bro_indw"] = initValue(((depthNow + 1) * 2).int64)
        vm.globals["__bro_atline"] = initValue(true)
      else:
        # declaration / statement chunk — own line at current depth
        if not vm.globals["__bro_atline"].boolVal:
          result.stringVal[].add('\n')
          for _ in 1 .. depthNow * 2:
            result.stringVal[].add(' ')
        result.stringVal[].add(rawStr)
        vm.globals["__bro_indw"] = initValue(0'i64) # content landed
        if rawStr[^1] != '\n':
          # self-terminated chunks (doc-block banners) keep their own newline
          result.stringVal[].add('\n')
        for _ in 1 .. depthNow * 2:
          result.stringVal[].add(' ')
        vm.globals["__bro_indw"] = initValue((depthNow * 2).int64)
        vm.globals["__bro_atline"] = initValue(true)
    of opcEmitCSS:
      let poses = co.strKeys[pcIdx]
      var pi = 0
      # selector mapping (first position pair)
      if poses.len >= 2:
        vm.globals["__bro_sourcemap_segments"].stringVal[].add(
          $result.stringVal[].len & "\x03" & $poses[pi] & "\x03" & $poses[pi + 1] & "\x03" & currentChunk.file & "\x02")
        pi += 2
      let props = stack.pop().objectVal
      let keys = props.keys
      let selectorName = stack.pop().stringVal[]
      let kind = stack.pop().intVal
      let prefix =
        case kind
        of 0: "." # class selector
        of 1: "#" # id selector
        of 2: ":" # pseudo-selector
        else: ""
      result.stringVal[].add(prefix & selectorName & "{")
      let prettyNow = vm.globals["__bro_pretty"].boolVal
      if prettyNow:
        # header content landed — clear pending indent before descending
        vm.globals["__bro_indw"] = initValue(0'i64)
        # structured rule: descend for declarations, matching raw-path layout
        vm.globals["__bro_depth"] = initValue((vm.globals["__bro_depth"].intVal + 1).int64)
        result.stringVal[].add('\n')
        for _ in 1 .. vm.globals["__bro_depth"].intVal.int * 2:
          result.stringVal[].add(' ')
        vm.globals["__bro_indw"] = initValue((vm.globals["__bro_depth"].intVal.int * 2).int64)
        vm.globals["__bro_atline"] = initValue(true)
      for i, key in keys:
        # per-property mapping
        if pi + 1 < poses.len:
          vm.globals["__bro_sourcemap_segments"].stringVal[].add(
            $result.stringVal[].len & "\x03" & $poses[pi] & "\x03" & $poses[pi + 1] & "\x03" & currentChunk.file & "\x02")
          pi += 2
        let val =
          case props.fields[i].typeId
          of tyString: props.fields[i].refVal.stringVal[]
          of tyInt:
            $(props.fields[i].intVal)
          of tyFloat:
            var fs = $(props.fields[i].floatVal)
            let fn = fs.len
            if fn > 2 and fs[fn - 2] == '.' and fs[fn - 1] == '0':
              fs.setLen(fn - 2) # integral float: "1000.0" → "1000"
            fs
          of tyBool:
            $(props.fields[i].boolVal)
          else: "<value>"

        if prettyNow and i > 0:
          # first declaration sits on the opener's fresh line; rest get their own
          result.stringVal[].add('\n')
          for _ in 1 .. vm.globals["__bro_depth"].intVal.int * 2:
            result.stringVal[].add(' ')
        result.stringVal[].add(key & ":" & val)
        if i < keys.len - 1:
          result.stringVal[].add(";")
        if prettyNow:
          vm.globals["__bro_atline"] = initValue(false)
          vm.globals["__bro_indw"] = initValue(0'i64) # declaration content landed
      if prettyNow:
        # drop pending auto-indent, dedent, place closing brace at parent level
        let indW = vm.globals["__bro_indw"].intVal.int
        if indW > 0:
          result.stringVal[].setLen(result.stringVal[].len - indW)
        if not vm.globals["__bro_atline"].boolVal:
          result.stringVal[].add('\n')
        elif indW > 0:
          discard # truncated indent left the '\n' from the opener in place
        vm.globals["__bro_depth"] = initValue((vm.globals["__bro_depth"].intVal - 1).int64)
        for _ in 1 .. vm.globals["__bro_depth"].intVal.int * 2:
          result.stringVal[].add(' ')
      result.stringVal[].add("}")
      if prettyNow:
        # leave the cursor at a fresh line for the next sibling rule
        result.stringVal[].add('\n')
        for _ in 1 .. vm.globals["__bro_depth"].intVal.int * 2:
          result.stringVal[].add(' ')
        vm.globals["__bro_indw"] = initValue((vm.globals["__bro_depth"].intVal.int * 2).int64)
        vm.globals["__bro_atline"] = initValue(true)
