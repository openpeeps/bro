# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
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
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else: break
    if lex.token == "$":
      lex.kind = tkVarSymbol
      return
    while lex.buf[lex.bufpos] == ' ':
      inc lex.bufpos
    if lex.buf[lex.bufpos] == '=':
      lex.kind =
        if isCSSVar:  tkVarAssgn
        else:         tkVarAssgn
      if lex.next("="): # `==` as infixOp
        lex.kind = tkVarCall
    # elif lex.buf[lex.bufpos] == ':':
    #   lex.kind = tkVarTyped
    #   if lex.next("="): 
    #     lex.kind =
    #       if isCSSVar:  tkCssVarDefRef
    #       else:         tkVarDefRef
    #     inc lex.bufpos, 2
    else:
      lex.kind = tkVarCall

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
      lex.kind = tkPipePipe
      add lex
    else:
      lex.kind = kind

  proc handleAccQuoted(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex.bufpos # `
    while true:
      case lex.buf[lex.bufpos]
      of '`':
        inc lex.bufpos
        lex.kind = kind
        break
      of EndOfFile:
        lex.setError("EOF reached before closing backtick string")
        break
      else:
        add lex

  proc handleImport(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    # inc lex.bufpos, len("import")
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

  proc handleDocBlock(lex: var Lexer, kind: TokenKind) =
    # lexReady lex
    while true:
      case lex.buf[lex.bufpos]
      of '*':
        add lex
        if lex.current == '/':
          add lex
          break
      of EndOfFile: break
      else: add lex
    lex.kind = kind

  proc customIntHandler(lex: var Lexer, kind: TokenKind) =
    # Handle integers and float numbers
    setLen(lex.token, 0)
    lex.startPos = lex.getColNumber(lex.bufpos)
    var toString, toFloat: bool
    while true:
      case lex.buf[lex.bufpos]
      of '0'..'9':
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
      # of 'a'..'z', 'A'..'Z', '_', '-':
      #   toString = true
      #   add lex.token, lex.buf[lex.bufpos]
      #   inc lex.bufpos
      of '.':
        if toFloat: break
        try:
          if lex.buf[lex.bufpos + 1] in {'0'..'9'}:
            toFloat = true
          else:
            lex.kind = tkInteger
            break
        except IndexDefect:
          toString = true
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
      else:
        if toFloat:
          lex.kind = tkFloat
        elif toString:
          lex.kind = tkString
        else:
          lex.kind = tkInteger
        break

const lexerSettings* =
  Settings(
    tkPrefix: "tk",
    lexerName: "Lexer",
    lexerTuple: "TokenTuple",
    lexerTokenKind: "TokenKind",
    tkModifier: defaultTokenModifier,      
    useDefaultIdent: true,
    useDefaultInt: false,
    keepUnknown: true,
    keepChar: true,
  )

registerTokens lexerSettings:
  symInt = tokenize(customIntHandler, '0'..'9')
  `case` = "case"
  `of` = "of"
  `bool` = ["true", "false"]
  colon = ':':
    varDefRef = '='
  semiColon = ';'
  comma = ','
  amp = '&':
    ampAmp = '&'
    pseudo = ':'
  pipe = '|':
    `pipePipe` = '|'
  multiply = '*'
  `mod` = '%'
  minus = '-'
  plus = '+'
  # caret = '^'
  # `var` = tokenize(handleVarDef, "var")
  # `const` = tokenize(handleVarDef, "const")
  `var` = "var"
  `const` = "const"
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
  lp = '('
  rp = ')'
  lb = '['
  rb = ']'
  lc = '{'
  rc = '}'
  # size units  
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
  varSymbol # $
  varCall = tokenize(handleVariable, '$')
  varTyped
  varAssgn
  fnCall
  class
  dot = '.'
  accQuoted = '`'
  divide = '/':
    doc = tokenize(handleDocBlock, '*')
    comment = '/' .. EOL
  `import` = tokenize(handleImport, "import")
  `include` = "include"
  # json = "json"
  at = '@':
    extend = "extend"
    mixCall = "mixin"
    importRule = "import"

  `and` = "and"
  `or` = "or"
  litArray = "array"
  litBool = "bool"
  litColor = tokenize(handleColorLit, "color")
  litFloat = "float"
  litFunction = "function"
  litInt = "int"
  litObject = "object"
  litSize = "size"
  litString = "string"
  litCSS = "css"
  litMixin = "mixin"
  litStream = "stream"
  litVoid = "void"

  id
  color
  fnDef = "fn"
  mixDef = "mix"
  `if` = "if"
  `elif` = "elif"
  `else` = "else"
  `for` = "for"
  `in` = "in"
  `when` = "when"
  `echo` = "echo"
  `assert` = "assert"
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
