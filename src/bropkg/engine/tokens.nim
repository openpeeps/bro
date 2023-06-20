# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[colors]
import toktok

export lexbase.close

static:
  Program.settings(false, "tk", keepUnknownChars = true)

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
    inc(lex) # $
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos) or current(lex) == '.':
        add lex
      else: break
    while lex.buf[lex.bufpos] == ' ':
      inc lex.bufpos
    if lex.buf[lex.bufpos] == '=':
      lex.kind = tkVar
      if lex.next("="):
        lex.kind = tkVarCall
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

  proc handleSnippets*(lex: var Lexer, kind: TokenKind) =    
    lex.startPos = lex.getColNumber(lex.bufpos)
    var k = tkPreview
    if lex.next("``html"):
      setLen(lex.token, 0)
      inc lex, 7
      skip lex
    else:
      lex.setError("Unknown markup. Use either `html` or `timl`")
      return
    while true:
      case current(lex):
      of '`':
        if lex.next("``"):
          lex.kind = k
          inc lex, 3
          return
        else:
          add lex
      of EndOfFile:
        lex.setError("EOF reached before end of snippet")
        return
      else:
        add lex
      skip lex
      lex.startPos = lex.getColNumber(lex.bufpos)

  proc handleAnd(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    add lex
    if current(lex) == ':':
      lex.kind = tkPseudoClass
      add lex
    elif current(lex) == '&':
      lex.kind = tkAndAnd
      add lex
    else:
      lex.kind = kind

tokens:
  A            > "a"
  Abbr         > "abbr"
  Acronym      > "acronym"
  Address      > "address"
  Applet       > "applet"
  Area         > "area"
  Article      > "article"
  Aside        > "aside"
  Audio        > "audio"
  Bold         > "b"
  Base         > "base"
  Basefont     > "basefont"
  Bdi          > "bdi"
  Bdo          > "bdo"
  Big          > "big"
  Blockquote   > "blockquote"
  Body         > "body"
  Br           > "br"
  Button       > "button"
  Canvas       > "canvas"
  Caption      > "caption"
  Center       > "center"
  Cite         > "cite"
  Code         > "code"
  Col          > "col"
  Colgroup     > "colgroup"
  Data         > "data"
  Datalist     > "datalist"
  DD           > "dd"
  Del          > "del"
  Details      > "details"
  DFN          > "dfn"
  Dialog       > "dialog"
  Dir          > "dir"
  Div          > "div"
  Doctype      > "doctype"
  DL           > "dl"
  DT           > "dt"
  EM           > "em"
  Embed        > "embed"
  Fieldset     > "fieldset"
  Figcaption   > "figcaption"
  Figure       > "figure"
  Font         > "font"
  Footer       > "footer"
  Form         > "form"
  Frame        > "frame"
  Frameset     > "frameset"
  H1           > "h1"
  H2           > "h2"
  H3           > "h3"
  H4           > "h4"
  H5           > "h5"
  H6           > "h6"
  Head         > "head"
  Header       > "header"
  Hr           > "hr"
  Html         > "html"
  Italic       > "i"
  Iframe       > "iframe"
  Img          > "img"
  Input        > "input"
  Ins          > "ins"
  Kbd          > "kbd"
  Label        > "label"
  Legend       > "legend"
  Li           > "li"
  Link         > "link"
  Main         > "main"
  Map          > "map"
  Mark         > "mark"
  Meta         > "meta"
  Meter        > "meter"
  Nav          > "nav"
  Noframes     > "noframes"
  Noscript     > "noscript"
  Object       > "object"
  Ol           > "ol"
  Optgroup     > "optgroup"
  Option       > "option"
  Output       > "output"
  Paragraph    > "p"
  Param        > "param"
  Pre          > "pre"
  Progress     > "progress"
  Quotation    > "q"
  RP           > "rp"
  RT           > "rt"
  Ruby         > "ruby"
  Strike       > "s"
  Samp         > "samp"
  Script       > "script"
  Section      > "section"
  Select       > "select"
  Small        > "small"
  Source       > "source"
  Span         > "span"
  Strike_Long  > "strike"
  Strong       > "strong"
  Style        > "style"
  Sub          > "sub"
  Summary      > "summary"
  Sup          > "sup"
  SVG          > "svg"
  Table        > "table"
  Tbody        > "tbody"
  TD           > "td"
  Template     > "template"
  Textarea     > "textarea"
  Tfoot        > "tfoot"
  TH           > "th"
  Thead        > "thead"
  Time         > "time"
  Title        > "title"
  TR           > "tr"
  Track        > "track"
  TT           > "tt"
  Underline    > "u"  
  UL           > "ul"
  # Var          > "var"
  Video        > "video"
  WBR          > "wbr"
  Root         > "root"
  Case        > "case"
  Of          > "of"
  AltAnd      > "and"
  AltOr       > "or"
  Colon       > ':'
  Comma       > ','
  And         > tokenize(handleAnd, '&')
  AndAnd        # && handleAnd
  PseudoClass   # &: handleAnd
  Pipe        > '|':
    OR        ? '|'   # ||
  Multi       > '*'
  Minus       > '-'
  Plus        > '+'
  Assign    > '=':
    EQ      ? '='   # ==
  NE        # != handledExclamation
  GT        > '>':
    GTE     ? '='
  LT        > '<':
    LTE     ? '='
  QMark     > '?'
  LPar      > '('
  RPar      > ')'
  LB        > '['
  RB        > ']'
  VarConcat > tokenize(handleCurlyVar, '{')
  LC        # '{'
  RC        > '}'
  ExcRule   > tokenize(handleExclamation, '!')
  Hash      > tokenize(handleHash, '#')
  Var       > tokenize(handleVariable, '$')
  VarCall
  VarCallAccessor
  Class       > tokenize(handleClassSelector, '.')
  Divide      > '/':
    Comment   > '/' .. EOL
  AtRule      > '@':
    Import    ? "import"
    Extend    ? "extend"
    Use       ? "use"
    Mixin     ? "mixin"
    # StartsWith  ? "startsWith"
    # EndsWith    ? "endsWith"
    # Count       ? "count"
    # Lowercase   ? "lowercase"
    # Uppercase   ? "uppercase"
    JSON        ? "json"
  Echo        > "echo"
  CSSCalc     > "calc"
  CSSAttr     > "attr"
  CSSConicGradient > "conic-gradient"
  CSSCounter > "counter"
  CSSCubicBezier > "cubic-bezier"
  CSSHSL  > "hsl"
  CSSHSLA > "hsla"
  CSSLinearGradient > "linear-gradient"
  CSSMax > "max"
  CSSmin > "min"
  CSSRadialGradient > "radial-gradient"
  CSSRepeatingConicGradient > "repeating-conic-gradient"
  CSSRepeatingLinearGradient > "repeating-linear-gradient"
  CSSRepeatingRadialGradient > "repeating-radial-gradient"
  CSSRGB > "rgb"
  CSSRGBA > "rgba"
  CSSVar > "var"

  # named colors
  ColorAliceblue > "aliceblue"
  ColorAntiquewhite > "antiquewhite"
  ColorAqua > "aqua"
  ColorAquamarine > "aquamarine"
  ColorAzure > "azure"
  ColorBeige > "beige"
  ColorBisque > "bisque"
  ColorBlack > "black"
  ColorBlanchedalmond > "blanchedalmond"
  ColorBlue > "blue"
  ColorBlueviolet > "blueviolet"
  ColorBrown > "brown"
  ColorBurlywood > "burlywood"
  ColorCadetblue > "cadetblue"
  ColorChartreuse > "chartreuse"
  ColorChocolate > "chocolate"
  ColorCoral > "coral"
  ColorCornflowerblue > "cornflowerblue"
  ColorCornsilk > "cornsilk"
  ColorCrimson > "crimson"
  ColorCyan > "cyan"
  ColorDarkblue > "darkblue"
  ColorDarkcyan > "darkcyan"
  ColorDarkgoldenrod > "darkgoldenrod"
  ColorDarkgray > "darkgray"
  ColorDarkgreen > "darkgreen"
  ColorDarkkhaki > "darkkhaki"
  ColorDarkmagenta > "darkmagenta"
  ColorDarkolivegreen > "darkolivegreen"
  ColorDarkorange > "darkorange"
  ColorDarkorchid > "darkorchid"
  ColorDarkred > "darkred"
  ColorDarksalmon > "darksalmon"
  ColorDarkseagreen > "darkseagreen"
  ColorDarkslateblue > "darkslateblue"
  ColorDarkslategray > "darkslategray"
  ColorDarkturquoise > "darkturquoise"
  ColorDarkviolet > "darkviolet"
  ColorDeeppink > "deeppink"
  ColorDeepskyblue > "deepskyblue"
  ColorDimgray > "dimgray"
  ColorDodgerblue > "dodgerblue"
  ColorFirebrick > "firebrick"
  ColorFloralwhite > "floralwhite"
  ColorForestgreen > "forestgreen"
  ColorFuchsia > "fuchsia"
  ColorGainsboro > "gainsboro"
  ColorGhostwhite > "ghostwhite"
  ColorGold > "gold"
  ColorGoldenrod > "goldenrod"
  ColorGray > "gray"
  ColorGrey > "grey"
  ColorGreen > "green"
  ColorGreenyellow > "greenyellow"
  ColorHoneydew > "honeydew"
  ColorHotpink > "hotpink"
  ColorIndianred > "indianred"
  ColorIndigo > "indigo"
  ColorIvory > "ivory"
  ColorKhaki > "khaki"
  ColorLavender > "lavender"
  ColorLavenderblush > "lavenderblush"
  ColorLawngreen > "lawngreen"
  ColorLemonchiffon > "lemonchiffon"
  ColorLightblue > "lightblue"
  ColorLightcoral > "lightcoral"
  ColorLightcyan > "lightcyan"
  ColorLightgoldenrodyellow > "lightgoldenrodyellow"
  ColorLightgray > "lightgray"
  ColorLightgreen > "lightgreen"
  ColorLightpink > "lightpink"
  ColorLightsalmon > "lightsalmon"
  ColorLightseagreen > "lightseagreen"
  ColorLightskyblue > "lightskyblue"
  ColorLightslategray > "lightslategray"
  ColorLightsteelblue > "lightsteelblue"
  ColorLightyellow > "lightyellow"
  ColorLime > "lime"
  ColorLimegreen > "limegreen"
  ColorLinen > "linen"
  ColorMagenta > "magenta"
  ColorMaroon > "maroon"
  ColorMediumaquamarine > "mediumaquamarine"
  ColorMediumblue > "mediumblue"
  ColorMediumorchid > "mediumorchid"
  ColorMediumpurple > "mediumpurple"
  ColorMediumseagreen > "mediumseagreen"
  ColorMediumslateblue > "mediumslateblue"
  ColorMediumspringgreen > "mediumspringgreen"
  ColorMediumturquoise > "mediumturquoise"
  ColorMediumvioletred > "mediumvioletred"
  ColorMidnightblue > "midnightblue"
  ColorMintcream > "mintcream"
  ColorMistyrose > "mistyrose"
  ColorMoccasin > "moccasin"
  ColorNavajowhite > "navajowhite"
  ColorNavy > "navy"
  ColorOldlace > "oldlace"
  ColorOlive > "olive"
  ColorOlivedrab > "olivedrab"
  ColorOrange > "orange"
  ColorOrangered > "orangered"
  ColorOrchid > "orchid"
  ColorPalegoldenrod > "palegoldenrod"
  ColorPalegreen > "palegreen"
  ColorPaleturquoise > "paleturquoise"
  ColorPalevioletred > "palevioletred"
  ColorPapayawhip > "papayawhip"
  ColorPeachpuff > "peachpuff"
  ColorPeru > "peru"
  ColorPink > "pink"
  ColorPlum > "plum"
  ColorPowderblue > "powderblue"
  ColorPurple > "purple"
  ColorRebeccapurple > "rebeccapurple"
  ColorRed > "red"
  ColorRosybrown > "rosybrown"
  ColorRoyalblue > "royalblue"
  ColorSaddlebrown > "saddlebrown"
  ColorSalmon > "salmon"
  ColorSandybrown > "sandybrown"
  ColorSeagreen > "seagreen"
  ColorSeashell > "seashell"
  ColorSienna > "sienna"
  ColorSilver > "silver"
  ColorSkyblue > "skyblue"
  ColorSlateblue > "slateblue"
  ColorSlategray > "slategray"
  ColorSnow > "snow"
  ColorSpringgreen > "springgreen"
  ColorSteelblue > "steelblue"
  ColorTan > "tan"
  ColorTeal > "teal"
  ColorThistle > "thistle"
  ColorTomato > "tomato"
  ColorTurquoise > "turquoise"
  ColorViolet > "violet"
  ColorWheat > "wheat"
  ColorWhite > "white"
  ColorWhitesmoke > "whitesmoke"
  ColorYellow > "yellow"
  ColorYellowgreen > "yellowgreen"
  ID
  Color
  Important
  Default
  Preview     > tokenize(handleSnippets, '`')
  FunctionCall
  FunctionStmt
  If          > "if"
  Elif        > "elif"
  Else        > "else"
  For         > "for"
  In          > "in"
  When        > "when"
  Bool        > {"true", "false"}