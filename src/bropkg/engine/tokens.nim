# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[colors]
import toktok

export lexbase.close

handlers:
  proc handleClassSelector(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    # inc lex
    add lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else:
        break
    lex.kind = tkClass 

  proc handleHash(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else: break
    if isColor("#" & lex.token):
      lex.token = "#" & lex.token
      lex.kind = tkColor
    else:
      lex.kind = tkID

  proc handleVariable(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    add(lex) # $
    var isCSSVar: bool
    if lex.current == '$':
      isCSSVar = true
      add lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos) or current(lex) == '.':
        add lex
      else: break
    if lex.token == "$":
      lex.setError("Invalid variable")
      return
    while lex.buf[lex.bufpos] == ' ':
      inc lex.bufpos
    if lex.buf[lex.bufpos] == '=':
      lex.kind =
        if isCSSVar:  tkCssVarDef
        else:         tkVarDef
      if lex.next("="):
        lex.kind = tkVarCall
      else: inc lex.bufpos
    elif lex.buf[lex.bufpos] == ':':
      lex.kind = tkVarTyped
      # inc lex.bufpos
    elif lex.token.contains("."):
      lex.kind = tkVarCallAccessor
    else:
      lex.kind = tkVarCall

  proc handleCurlyVar(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex
    if current(lex) == '$':
      lex.handleVariable(kind)
      if current(lex) == '}':
        inc lex
        lex.kind = tkVarConcat
      else:
        lex.setError("Missing closing curly bracket")
    else:
      lex.kind = tkLC
      lex.token = "{"

  proc handleExclamation(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else:
        if lex.buf[lex.bufpos] == '=':
          add lex
          lex.kind = tkNE
          return
        break
    if lex.token == "important":
      lex.kind = tkImportant
    elif lex.token == "default":
      lex.kind = tkDefault
    else: discard # TODO error

  proc handleAnd(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    add lex
    if current(lex) == ':':
      lex.kind = tkPseudo
      add lex
    elif current(lex) == '&':
      lex.kind = tkAndAnd
      add lex
    else:
      lex.kind = kind

  proc handleAccQuoted(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex.bufpos # `
    while true:
      case lex.buf[lex.bufpos]
      of '$':
        add lex.token, '$' 
        inc lex.bufpos
        if lex.current == '{':
          inc lex.bufpos
          var varName: string
          while true:
            case lex.buf[lex.bufpos]:
            of '}':
              inc lex.bufpos
              break
            of EndOfFile, NewLines:
              lex.setError("EOF reached before closing curly bracket")
              return
            of IdentChars:
              add varName, lex.buf[lex.bufpos]
              inc lex.bufpos
            else:
              lex.setError("Invalid variable name")
              return
          if varName.len > 0:
            add lex.token, varName
            add lex.attr, varName
            setLen(varName, 0)
      of '`':
        inc lex.bufpos
        lex.kind = kind
        return
      of EndOfFile:
        lex.setError("EOF reached before closing accent quoted string")
        return
      else:
        add lex

  proc handleImport(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex.bufpos, len("@import")
    skip lex
    reset(lex.wsno) # dont count left wsno
    var fName: string
    while true:
      case lex.buf[lex.bufpos]:
      of NewLines, EndOfFile:
        if fName.len != 0:
          lex.attr.add(fName)
        break
      of ',':
        # imports separated by comma
        lex.attr.add(fName)
        setLen(fName, 0)
        inc lex.bufpos
      of ' ':
        inc lex.bufpos
      else:
        add fName, lex.buf[lex.bufpos]
        inc lex.bufpos
    lex.kind = kind

  proc handleColorLit(lex: var Lexer, kind: TokenKind) =
    skip lex
    if lex.buf[lex.bufpos] == ':':
      lex.kind = tkIdentifier
    else:
      lex.kind = kind

registerTokens defaultSettings:
  `case` = "case"
  `of` = "of"
  andLit = "and"
  orLit = "or"
  `bool` = ["true", "false"]
  colon = ':'
  comma = ','
  `and` = '&':
    andAnd = '&'
    pseudo = ':'
  pipe = '|':
    `or` = '|'
  multiply = '*'
  minus = '-'
  plus = '+'
  assign = '=':
    eq = '='
  `not` = '!':
    ne = '='
    default = "default"
    important = "important"
  gt = '>':
    gte = '='
  lt ='<':
    lte = '='
  quest = '?'
  lpar = '('
  rpar = ')'
  lb = '['
  rb = ']'
  # lc = '{'
  lc
  rc = '}'
  
  mm = "mm"
  cm = "cm"
  `in` = "in"
  px = "px"
  pt = "pt"
  pc = "pc"
  
  em = "em"
  ex = "ex"
  ch = "ch"
  rem = "rem"
  vw = "vw"
  vh = "vh"
  vmin = "vmin"
  vmax = "vmax"

  # excRule = tokenize(handleExclamation, '!')
  hash = tokenize(handleHash, '#')
  varConcat = tokenize(handleCurlyVar, '{')
  varDef = tokenize(handleVariable, '$')
  cssVarDef # $$default-size 
  varTyped
  varCall
  varCallAccessor
  # class = tokenize(handleClassSelector, '.')
  class
  dotExpr = '.'
  accQuoted = tokenize(handleAccQuoted, '`')
  divide = '/':
    comment = '/' .. EOL
  at = '@':
    `import` = tokenize(handleImport, "import")
    extend = "extend"
    use = "use"
    mix = "mixin"
    json = "json"

  arrayLit = "array"
  boolLit = "bool"
  colorLit = tokenize(handleColorLit, "color")
  floatLit = "float"
  functionLit = "function"
  intLit = "int"
  objectLit = "object"
  sizeLit = "size"
  stringLit = "string"
  id
  color
  fnDef = "fn"
  mixDef = "mix"
  functionCall
  `if` = "if"
  `elif` = "elif"
  `else` = "else"
  `for` = "for"
  `in` = "in"
  `when` = "when"
  `echo` = "echo"
  `return` = "return"
  this = "this"
  selectorType = "Selector"
  classType = "Class"
  idType = "ID"

  # CSSCalc     > "calc"
  # CSSAttr     > "attr"
  # CSSConicGradient > "conic-gradient"
  # CSSCounter > "counter"
  # CSSCubicBezier > "cubic-bezier"
  # CSSHSL  > "hsl"
  # CSSHSLA > "hsla"
  # CSSLinearGradient > "linear-gradient"
  # CSSMax > "max"
  # CSSmin > "min"
  # CSSRadialGradient > "radial-gradient"
  # CSSRepeatingConicGradient > "repeating-conic-gradient"
  # CSSRepeatingLinearGradient > "repeating-linear-gradient"
  # CSSRepeatingRadialGradient > "repeating-radial-gradient"
  # CSSRGB > "rgb"
  # CSSRGBA > "rgba"
  # CSSVar > "var"
  # named colors
  colorAliceblue = "aliceblue"
  colorAntiquewhite = "antiquewhite"
  colorAqua = "aqua"
  colorAquamarine = "aquamarine"
  colorAzure = "azure"
  colorBeige = "beige"
  colorBisque = "bisque"
  colorBlack = "black"
  colorBlanchedalmond = "blanchedalmond"
  colorBlue = "blue"
  colorBlueviolet = "blueviolet"
  colorBrown = "brown"
  colorBurlywood = "burlywood"
  colorCadetblue = "cadetblue"
  colorChartreuse = "chartreuse"
  colorChocolate = "chocolate"
  colorCoral = "coral"
  colorCornflowerblue = "cornflowerblue"
  colorCornsilk = "cornsilk"
  colorCrimson = "crimson"
  colorCyan = "cyan"
  colorDarkblue = "darkblue"
  colorDarkcyan = "darkcyan"
  colorDarkgoldenrod = "darkgoldenrod"
  colorDarkgray = "darkgray"
  colorDarkgreen = "darkgreen"
  colorDarkkhaki = "darkkhaki"
  colorDarkmagenta = "darkmagenta"
  colorDarkolivegreen = "darkolivegreen"
  colorDarkorange = "darkorange"
  colorDarkorchid = "darkorchid"
  colorDarkred = "darkred"
  colorDarksalmon = "darksalmon"
  colorDarkseagreen = "darkseagreen"
  colorDarkslateblue = "darkslateblue"
  colorDarkslategray = "darkslategray"
  colorDarkturquoise = "darkturquoise"
  colorDarkviolet = "darkviolet"
  colorDeeppink = "deeppink"
  colorDeepskyblue = "deepskyblue"
  colorDimgray = "dimgray"
  colorDodgerblue = "dodgerblue"
  colorFirebrick = "firebrick"
  colorFloralwhite = "floralwhite"
  colorForestgreen = "forestgreen"
  colorFuchsia = "fuchsia"
  colorGainsboro = "gainsboro"
  colorGhostwhite = "ghostwhite"
  colorGold = "gold"
  colorGoldenrod = "goldenrod"
  colorGray = "gray"
  colorGrey = "grey"
  colorGreen = "green"
  colorGreenyellow = "greenyellow"
  colorHoneydew = "honeydew"
  colorHotpink = "hotpink"
  colorIndianred = "indianred"
  colorIndigo = "indigo"
  colorIvory = "ivory"
  colorKhaki = "khaki"
  colorLavender = "lavender"
  colorLavenderblush = "lavenderblush"
  colorLawngreen = "lawngreen"
  colorLemonchiffon = "lemonchiffon"
  colorLightblue = "lightblue"
  colorLightcoral = "lightcoral"
  colorLightcyan = "lightcyan"
  colorLightgoldenrodyellow = "lightgoldenrodyellow"
  colorLightgray = "lightgray"
  colorLightgreen = "lightgreen"
  colorLightpink = "lightpink"
  colorLightsalmon = "lightsalmon"
  colorLightseagreen = "lightseagreen"
  colorLightskyblue = "lightskyblue"
  colorLightslategray = "lightslategray"
  colorLightsteelblue = "lightsteelblue"
  colorLightyellow = "lightyellow"
  colorLime = "lime"
  colorLimegreen = "limegreen"
  colorLinen = "linen"
  colorMagenta = "magenta"
  colorMaroon = "maroon"
  colorMediumaquamarine = "mediumaquamarine"
  colorMediumblue = "mediumblue"
  colorMediumorchid = "mediumorchid"
  colorMediumpurple = "mediumpurple"
  colorMediumseagreen = "mediumseagreen"
  colorMediumslateblue = "mediumslateblue"
  colorMediumspringgreen = "mediumspringgreen"
  colorMediumturquoise = "mediumturquoise"
  colorMediumvioletred = "mediumvioletred"
  colorMidnightblue = "midnightblue"
  colorMintcream = "mintcream"
  colorMistyrose = "mistyrose"
  colorMoccasin = "moccasin"
  colorNavajowhite = "navajowhite"
  colorNavy = "navy"
  colorOldlace = "oldlace"
  colorOlive = "olive"
  colorOlivedrab = "olivedrab"
  colorOrange = "orange"
  colorOrangered = "orangered"
  colorOrchid = "orchid"
  colorPalegoldenrod = "palegoldenrod"
  colorPalegreen = "palegreen"
  colorPaleturquoise = "paleturquoise"
  colorPalevioletred = "palevioletred"
  colorPapayawhip = "papayawhip"
  colorPeachpuff = "peachpuff"
  colorPeru = "peru"
  colorPink = "pink"
  colorPlum = "plum"
  colorPowderblue = "powderblue"
  colorPurple = "purple"
  colorRebeccapurple = "rebeccapurple"
  colorRed = "red"
  colorRosybrown = "rosybrown"
  colorRoyalblue = "royalblue"
  colorSaddlebrown = "saddlebrown"
  colorSalmon = "salmon"
  colorSandybrown = "sandybrown"
  colorSeagreen = "seagreen"
  colorSeashell = "seashell"
  colorSienna = "sienna"
  colorSilver = "silver"
  colorSkyblue = "skyblue"
  colorSlateblue = "slateblue"
  colorSlategray = "slategray"
  colorSnow = "snow"
  colorSpringgreen = "springgreen"
  colorSteelblue = "steelblue"
  colorTan = "tan"
  colorTeal = "teal"
  colorThistle = "thistle"
  colorTomato = "tomato"
  colorTurquoise = "turquoise"
  colorViolet = "violet"
  colorWheat = "wheat"
  colorWhite = "white"
  colorWhitesmoke = "whitesmoke"
  colorYellow = "yellow"
  colorYellowgreen = "yellowgreen"