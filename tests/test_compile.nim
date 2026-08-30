import ../src/bro/engine/vancodegen
import unittest
import std/[options, strutils, tables, os]
import pkg/openparser/json

import ../src/bro/engine/parser

import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value]
import pkg/vancode/interpreter/resolver

import ../src/bro/engine/stdlib/[libsystem]

proc compile(code: string): string =
  var program: Ast
  parser.parseScript(program, code, "test.bass")

  let mainChunk = newChunk("test.bass")
  var script = newScript(mainChunk)
  var module = newModule("test", some("test.bass"))

  let systemModule = libsystem.loadLibrary(script, newJObject(), newJObject())
  module.load(systemModule)
  script.stdpos = script.procs.high

  var gen = initCodeGen(script, module, mainChunk)
  gen.genScript(program, none(string))

  let virtualMachine = newVirtualMachine(VMPreferences())
  result = virtualMachine.interpret(script, mainChunk).stringVal[]

proc compileFile(path: string): string =
  ## Full pipeline for a real file on disk — mirrors the CLI build path,
  ## including the import parserCallback so `.bass` imports resolve.
  proc cb(astProgram: var Ast, p: string, resolver: FileResolver) =
    parser.parseScript(astProgram, readFile(p), p)

  var program: Ast
  parser.parseScript(program, readFile(path), path)
  let mainChunk = newChunk(path)
  var script = newScript(mainChunk)
  var module = newModule(path.extractFilename, some(path))
  let systemModule = libsystem.loadLibrary(script, newJObject(), newJObject())
  module.load(systemModule)
  script.stdpos = script.procs.high

  var gen = initCodeGen(script, module, mainChunk, manager = nil, parserCallback = cb)
  gen.genScript(program, none(string))

  let virtualMachine = newVirtualMachine(VMPreferences())
  result = virtualMachine.interpret(script, mainChunk).stringVal[]

suite "compilation tests":
  test "compile simple class selector":
    let css = compile(".foo { color: red; }")
    check css == ".foo{color:red}"

  test "compile class with multiple properties":
    let css = compile("""
  .card {
    color: blue;
    font-size: 16px;
  }
  """)
    check css == ".card{color:blue;font-size:16px}"

  test "compile id selector":
    let css = compile("#header { width: 100px; }")
    check css == "#header{width:100px}"

  test "compile pseudo selector":
    let css = compile(":root { font-size: 16px; }")
    check css == ":root{font-size:16px}"

  test "compile element selector":
    let css = compile("h1 { color: red; }")
    check css == "h1{color:red}"

  test "compile multiple selectors comma separated":
    let css = compile("h1, btn { color: red; }")
    check css == "h1,btn{color:red}"

  test "compile element selector followed by rules on same line":
    let css = compile("a, btn:hover { padding-top: 10px; }.p-0 { padding: 0; }")
    check css == "a,btn:hover{padding-top:10px}.p-0{padding:0}"

  test "compile attribute selector":
    let css = compile("[data-bs-theme=dark] { color: red; }")
    check css == "[data-bs-theme=dark]{color:red}"

  test "compile attribute selector with quoted value":
    let css = compile("[data-bs-theme=\"dark\"] { color: red; }")
    check css == "[data-bs-theme=\"dark\"]{color:red}"

  test "compile attribute selector on class":
    let css = compile(".dropdown[data-bs-popper] { padding: 0; }")
    check css == ".dropdown[data-bs-popper]{padding:0}"

  test "compile attribute selector with caret operator":
    let css = compile("a[href^=\"http\"] { color: blue; }")
    check css == "a[href^=\"http\"]{color:blue}"

  test "compile attribute selector with tilde operator":
    let css = compile("[data-x~=foo] { display: block; }")
    check css == "[data-x~=foo]{display:block}"

  test "compile attribute selector with dollar operator":
    let css = compile("[data-x$=\"suffix\"] { display: none; }")
    check css == "[data-x$=\"suffix\"]{display:none}"

  test "compile attribute selector with pipe operator":
    let css = compile("[data-x|=en] { width: 10px; }")
    check css == "[data-x|=en]{width:10px}"

  test "compile element with attribute and pseudo":
    let css = compile("input[type=\"checkbox\"]:checked { color: green; }")
    check css == "input[type=\"checkbox\"]:checked{color:green}"

  test "compile minified css without spaces":
    let css = compile("body{color:red}.foo{padding:0}")
    check css == "body{color:red}.foo{padding:0}"

  test "compile hex color starting with digit":
    let css = compile(".foo{color:#0d6efd}")
    check css == ".foo{color:#0d6efd}"

  test "compile leading-dot float":
    let css = compile(".foo{margin-top:.125rem}")
    check css == ".foo{margin-top:0.125rem}"

  test "compile descendant selector after attribute":
    let css = compile("[data-bs-theme=\"dark\"] .dropdown-menu { color: red; }")
    check css == "[data-bs-theme=\"dark\"] .dropdown-menu{color:red}"

  test "compile attribute with comma-separated selectors":
    let css = compile("a[href^=\"http\"], [data-x^=\"y\"] { color: blue; }")
    check css == "a[href^=\"http\"],[data-x^=\"y\"]{color:blue}"

  test "compile adjacent sibling combinator":
    let css = compile(".btn-check:checked+.btn { color: red; }")
    check css == ".btn-check:checked+.btn{color:red}"

  test "compile child combinator":
    let css = compile(".parent>.child { color: red; }")
    check css == ".parent>.child{color:red}"

  test "compile var() css function":
    let css = compile(".btn { color: var(--bs-btn-hover-color); }")
    check css == ".btn{color:var(--bs-btn-hover-color)}"

  test "compile css variable declarations":
    let css = compile(":root { --bs-blue: #0d6efd; --bs-breakpoint-md: 768px; }")
    check css == ":root{--bs-blue:#0d6efd;--bs-breakpoint-md:768px}"

  test "compile pseudo-element":
    let css = compile(".foo::before { display: block; }")
    check css == ".foo::before{display:block}"

  test "compile important modifier":
    let css = compile(".foo { color: red !important; }")
    check css == ".foo{color:red !important}"

  test "compile descendant element selectors":
    let css = compile("""
  ol ol,
  ul ul,
  ol ul,
  ul ol {
    margin-bottom: 0;
  }
  """)
    check css == "ol ol,ul ul,ol ul,ul ol{margin-bottom:0}"

  test "compile nested element selector in at-rule":
    let css = compile("@media (min-width: 768px) { ol li { color: blue; } }")
    check css == "@media (min-width: 768px){ol li{color:blue}}"

  test "compile is() functional pseudo":
    let css = compile(".table :is(thead,tbody,tfoot)>tr>th,td { padding: .5rem; }")
    check css == ".table :is(thead,tbody,tfoot)>tr>th,td{padding:0.5rem}"

  test "compile not() functional pseudo":
    let css = compile(".visually-hidden:not(caption) { position: absolute; }")
    check css == ".visually-hidden:not(caption){position:absolute}"

  test "compile nth-child functional pseudo":
    let css = compile(".x:nth-child(2n+1) { color: red; }")
    check css == ".x:nth-child(2n+1){color:red}"

  test "compile compound class selector":
    let css = compile(".offcanvas.offcanvas-start { color: red; }")
    check css == ".offcanvas.offcanvas-start{color:red}"

  test "compile duplicate property keys (vendor fallback)":
    let css = compile("th { text-align: inherit; text-align: -webkit-match-parent; }")
    check css == "th{text-align:inherit;text-align:-webkit-match-parent}"

  test "compile negative space-separated values":
    let css = compile(".x { margin: -0.375rem -0.75rem; }")
    check css == ".x{margin:-0.375rem -0.75rem}"

  test "compile nested comma-separated values":
    let css = compile(".x { background-position: right 0.75rem center, center right 2.25rem; }")
    check css == ".x{background-position:right 0.75rem center, center right 2.25rem}"

  test "compile indent based class selector":
    let css = compile("""
  .foo
    color: red
    font-size: 14px
  """)
    check css == ".foo{color:red;font-size:14px}"

  test "compile nested selector":
    let css = compile("""
  .parent
    .child
      color: blue
  """)
    check css == ".parent .child{color:blue}"

  test "compile class with pseudo selector":
    let css = compile("""
  .btn:hover
    color: blue
  """)
    check css == ".btn:hover{color:blue}"

  test "compile unit values":
    let css = compile(".box { width: 100px; }")
    check css == ".box{width:100px}"

  test "compile float values":
    let css = compile(".a { size: 1.5; }")
    check css == ".a{size:1.5}"

  test "compile string value":
    let css = compile(".c { font-family: \"Arial\"; }")
    check css == ".c{font-family:\"Arial\"}"

  test "compile multiple values":
    let css = compile(".pad { margin: 10px 20px; }")
    check css == ".pad{margin:10px 20px}"

  test "compile multiple nested selectors":
    let css = compile("""
  .a
    .b
      color: red
    .c
      color: blue
  """)
    check css == ".a .b{color:red}.a .c{color:blue}"

  test "compile deeply nested selectors":
    let css = compile("""
  .x
    .y
      .z
        color: red
  """)
    check css == ".x .y .z{color:red}"

  test "compile css custom property":
    let css = compile("""
  :root {
    --primary: #333;
  }
  """)
    check css == ":root{--primary:#333}"

  test "compile hex color value":
    let css = compile(".foo { color: #ff0000; }")
    check css == ".foo{color:#ff0000}"

  test "compile empty selector":
    let css = compile(".empty { }")
    check css == ".empty{}"

  test "compile multiple top-level selectors":
    let css = compile("""
  .a { color: red; }
  .b { color: blue; }
  """)
    check css == ".a{color:red}.b{color:blue}"

  test "compile indent based with braces":
    let css = compile("""
  .foo {
    color: red
  }
  """)
    check css == ".foo{color:red}"

  test "compile variable declaration and usage":
    let css = compile("""
  var $primary = red
  .foo { color: $primary; }
  """)
    check css == ".foo{color:#FF0000}"

  test "compile let declaration":
    let css = compile("""
  let $size = 16px
  .foo { font-size: $size; }
  """)
    check css == ".foo{font-size:16px}"

  test "compile multiple variable usage":
    let css = compile("""
  var $a = 10
  var $b = 20
  .foo { width: $a; height: $b; }
  """)
    check css == ".foo{width:10;height:20}"

  test "compile variable reference in selector block":
    let css = compile("""
  let $col = blue
  .foo
    color: $col
    background: $col
  """)
    check css == ".foo{color:#0000FF;background:#0000FF}"

  test "compile arithmetic in value":
    let css = compile("""
  let $base = 10
  .foo { width: $base + 5; }
  """)
    check css == ".foo{width:15}"

  test "compile string variable":
    let css = compile("""
  let $name = "hello"
  .foo { content: $name; }
  """)
    check css == ".foo{content:hello}"

  test "compile @media query":
    let css = compile("""
  @media (max-width: 768px)
    .foo
      color: red
  """)
    check css == "@media (max-width: 768px){.foo{color:red}}"

  test "compile @supports":
    let css = compile("""
  @supports (display: grid)
    .foo { color: red; }
  """)
    check css == "@supports (display: grid){.foo{color:red}}"

  test "compile @font-face":
    let css = compile("""
  @font-face {
    font-family: "Custom";
    src: url("custom.woff2");
  }
  """)
    check css == "@font-face{font-family:\"Custom\";src:url(\"custom.woff2\")}"

  test "compile @keyframes":
    let css = compile("""
  @keyframes slide
    from
      opacity: 0
    to
      opacity: 1
  """)
    check css == "@keyframes slide{from{opacity:0}to{opacity:1}}"

  test "compile @import":
    let css = compile("@import url(\"style.css\");")
    check css == "@import url(\"style.css\");"

  test "compile @media with comma-separated selectors":
    let css = compile("""
  @media (min-width: 480px)
    .foo, .bar
      color: blue
  """)
    check css == "@media (min-width: 480px){.foo,.bar{color:blue}}"

  test "compile nested @media inside selector":
    let css = compile("""
  .parent
    @media (max-width: 768px)
      .child
        color: blue
  """)
    check css == ".parent{@media (max-width: 768px){.child{color:blue}}}"

  test "compile @media brace-delimited":
    let css = compile("@media (max-width: 768px) { .foo { color: red; } }")
    check css == "@media (max-width: 768px){.foo{color:red}}"

  test "compile @supports simple":
    let css = compile("@supports (display: grid) { .foo { color: red; } }")
    check css == "@supports (display: grid){.foo{color:red}}"

  test "compile @supports with not":
    let css = compile("@supports not (display: grid) { .foo { color: red; } }")
    check css == "@supports not (display: grid){.foo{color:red}}"

  test "compile @layer unnamed":
    let css = compile("""
  @layer
    .foo
      color: red
  """)
    check css == "@layer{.foo{color:red}}"

  test "compile @layer multiple named":
    let css = compile("@layer base, theme;")
    check css == "@layer base, theme;"

  test "compile @font-face with single descriptor":
    let css = compile("@font-face { font-family: \"Custom\"; }")
    check css == "@font-face{font-family:\"Custom\"}"

  test "compile @keyframes brace-delimited":
    let css = compile("@keyframes slide { from { opacity: 0; } to { opacity: 1; } }")
    check css == "@keyframes slide{from{opacity:0}to{opacity:1}}"

  test "compile @keyframes with percentage":
    let css = compile("""
  @keyframes slide
    0%
      opacity: 0
    100%
      opacity: 1
  """)
    check css == "@keyframes slide{0%{opacity:0}100%{opacity:1}}"

  test "compile @charset":
    let css = compile("@charset \"utf-8\";")
    check css == "@charset \"utf-8\";"

  test "compile @namespace":
    let css = compile("@namespace url(\"http://www.w3.org/1999/xhtml\");")
    check css == "@namespace url(\"http://www.w3.org/1999/xhtml\");"

  test "compile property after @media":
    let css = compile("""
  @media (max-width: 768px)
    .foo
      color: red
  .bar
    color: blue
  """)
    check css == "@media (max-width: 768px){.foo{color:red}}.bar{color:blue}"

suite "Phase 1: universal selector":
  test "compile universal selector (brace)":
    check compile("* { margin: 0; }") == "*{margin:0}"

  test "compile universal selector (indent)":
    check compile("*\n  margin: 0") == "*{margin:0}"

  test "compile universal selector with properties":
    check compile("* { box-sizing: border-box; margin: 0; padding: 0; }") ==
      "*{box-sizing:border-box;margin:0;padding:0}"

suite "Phase 1: keyframes comma selectors":
  test "compile keyframes with comma-separated selectors (brace)":
    check compile("@keyframes slide { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }") ==
      "@keyframes slide{0%,100%{opacity:1}50%{opacity:0}}"

  test "compile keyframes with comma-separated selectors (indent)":
    check compile("@keyframes slide\n  0%, 100%\n    opacity: 1\n  50%\n    opacity: 0") ==
      "@keyframes slide{0%,100%{opacity:1}50%{opacity:0}}"

  test "compile keyframes from/to":
    check compile("@keyframes fade { from { opacity: 0; } to { opacity: 1; } }") ==
      "@keyframes fade{from{opacity:0}to{opacity:1}}"

  test "compile keyframes percentage range":
    check compile("@keyframes move { 0% { left: 0; } 25%, 75% { left: 50%; } 100% { left: 100%; } }") ==
      "@keyframes move{0%{left:0}25%,75%{left:50%}100%{left:100%}}"

suite "Phase 1: opaque call-arg parsing":
  test "compile rgb with commas":
    check compile(".a { color: rgb(255, 0, 0); }") == ".a{color:rgb(255, 0, 0)}"

  test "compile rgb with spaces (modern syntax)":
    check compile(".a { color: rgb(13 110 253); }") == ".a{color:rgb(13 110 253)}"

  test "compile rgb with slash alpha (modern syntax)":
    check compile(".a { color: rgb(13 110 253 / 50%); }") == ".a{color:rgb(13 110 253 / 50%)}"

  test "compile rgba":
    check compile(".a { color: rgba(255, 0, 0, 0.5); }") == ".a{color:rgba(255, 0, 0, 0.5)}"

  test "compile linear-gradient spaces preserved":
    check compile(".a { background: linear-gradient(to right, red, blue); }") ==
      ".a{background:linear-gradient(to right, red, blue)}"

  test "compile linear-gradient with angle":
    check compile(".a { background: linear-gradient(45deg, red, blue); }") ==
      ".a{background:linear-gradient(45deg, red, blue)}"

  test "compile radial-gradient":
    check compile(".a { background: radial-gradient(circle at center, red, blue); }") ==
      ".a{background:radial-gradient(circle at center, red, blue)}"

  test "compile url unquoted":
    check compile(".a { background: url(img.png); }") == ".a{background:url(img.png)}"

  test "compile url quoted":
    check compile(".a { background: url(\"img.png\"); }") == ".a{background:url(\"img.png\")}"

  test "compile calc":
    check compile(".a { width: calc(100% - 2rem); }") == ".a{width:calc(100% - 2rem)}"

  test "compile clamp":
    check compile(".a { width: clamp(1rem, 2.5vw, 2rem); }") ==
      ".a{width:clamp(1rem, 2.5vw, 2rem)}"

  test "compile min":
    check compile(".a { width: min(100%, 500px); }") == ".a{width:min(100%, 500px)}"

  test "compile max":
    check compile(".a { width: max(100%, 500px); }") == ".a{width:max(100%, 500px)}"

  test "compile env":
    check compile(".a { padding-top: env(safe-area-inset-top); }") ==
      ".a{padding-top:env(safe-area-inset-top)}"

  test "compile counter":
    check compile(".a::before { content: counter(x, upper-roman); }") ==
      ".a::before{content:counter(x, upper-roman)}"

  test "compile attr":
    check compile(".a::before { content: attr(data-label); }") ==
      ".a::before{content:attr(data-label)}"

  test "compile repeat/minmax":
    check compile(".a { grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); }") ==
      ".a{grid-template-columns:repeat(auto-fill, minmax(200px, 1fr))}"

  test "compile box-shadow multi-value":
    check compile(".a { box-shadow: 0 1px 2px rgba(0,0,0,.3), inset 0 0 0 1px red; }") ==
      ".a{box-shadow:0 1px 2px rgba(0,0,0,.3), inset 0 0 0 1px red}"

  test "compile var() with fallback":
    check compile(".a { color: var(--x, red); }") == ".a{color:var(--x, red)}"

  test "compile nested function calls":
    check compile(".a { background: linear-gradient(to right, rgb(255, 0, 0), rgb(0, 0, 255)); }") ==
      ".a{background:linear-gradient(to right, rgb(255, 0, 0), rgb(0, 0, 255))}"

  test "compile filter drop-shadow":
    check compile(".a { filter: drop-shadow(0 0 5px rgba(0,0,0,.5)); }") ==
      ".a{filter:drop-shadow(0 0 5px rgba(0,0,0,.5))}"

  test "compile transform functions":
    check compile(".a { transform: translate(-50%, -50%) rotate(45deg); }") ==
      ".a{transform:translate(-50%, -50%) rotate(45deg)}"

  test "compile transition shorthand":
    check compile(".a { transition: all .3s ease-in-out; }") ==
      ".a{transition:all 0.3s ease-in-out}"

suite "Phase 1: true/false/null values":
  test "compile true value":
    check compile(".a { inherits: true; }") == ".a{inherits:true}"

  test "compile false value":
    check compile(".a { inherits: false; }") == ".a{inherits:false}"

  test "compile null value":
    check compile(".a { content: null; }") == ".a{content:null}"

  test "compile true value (indent)":
    check compile(".a\n  inherits: true") == ".a{inherits:true}"

  test "compile false value (indent)":
    check compile(".a\n  inherits: false") == ".a{inherits:false}"

  test "compile multiple keyword values":
    check compile(".a { inherits: false; content: null; }") ==
      ".a{inherits:false;content:null}"

suite "Phase 1: string escape round-trip":
  test "compile unicode escape":
    check compile(".a { content: \"\\201E\"; }") == ".a{content:\"\\201E\"}"

  test "compile backslash escape":
    check compile(".a { content: \"a\\\\b\"; }") == ".a{content:\"a\\b\"}"

  test "compile escaped quote":
    check compile(".a { content: \"a\\\"b\"; }") == ".a{content:\"a\\\"b\"}"

suite "Phase 1: attribute selector flags":
  test "compile attribute with case-insensitive flag":
    check compile("[data-x=foo i] { display: block; }") ==
      "[data-x=foo i]{display:block}"

  test "compile attribute with case-insensitive flag on class":
    check compile(".a[data-x=bar s] { color: red; }") ==
      ".a[data-x=bar s]{color:red}"

  test "compile attribute flag preserves spacing":
    check compile("[type=\"text\" i] { border: 1px; }") ==
      "[type=\"text\" i]{border:1px}"

suite "Phase 1: at-rule prelude quoting":
  test "compile @charset preserves quotes":
    check compile("@charset \"utf-8\";") == "@charset \"utf-8\";"

  test "compile @import preserves url quotes":
    check compile("@import url(\"style.css\");") == "@import url(\"style.css\");"

  test "compile @namespace preserves url quotes":
    check compile("@namespace url(\"http://www.w3.org/1999/xhtml\");") ==
      "@namespace url(\"http://www.w3.org/1999/xhtml\");"

  test "compile @import unquoted":
    check compile("@import url(style.css);") == "@import url(style.css);"

suite "Phase 1: validator warn-only (no crash)":
  test "compile box-shadow multi-value (no crash)":
    let css = compile(".a { box-shadow: 0 1px 2px rgba(0,0,0,.3), inset 0 0 0 1px red; }")
    check css.len > 0
    check "box-shadow" in css

  test "compile repeat/minmax (no crash)":
    let css = compile(".a { grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); }")
    check css.len > 0
    check "repeat" in css

  test "compile color-mix (no crash)":
    let css = compile(".a { background: color-mix(in oklab, red, blue); }")
    check css.len > 0

  test "compile oklch (no crash)":
    let css = compile(".a { color: oklch(0.5 0.2 120 / 40%); }")
    check css.len > 0

suite "Phase 1: mixed brace/indent syntax":
  test "compile brace rule with indent-nested rule":
    check compile(".foo {\n  .bar\n    color: red\n}") == ".foo .bar{color:red}"

  test "compile indent rule with brace-nested rule":
    check compile(".foo\n  .bar {\n    color: red\n  }") == ".foo .bar{color:red}"

  test "compile brace @media with indent selectors":
    check compile("@media (max-width: 768px) {\n  .foo\n    color: red\n}") ==
      "@media (max-width: 768px){.foo{color:red}}"

  test "compile indent @media with brace selectors":
    check compile("@media (max-width: 768px)\n  .foo { color: red; }") ==
      "@media (max-width: 768px){.foo{color:red}}"

suite "Phase 2: Sass-style nesting":
  test "simple descendant nesting (indent)":
    check compile(".parent\n  .child\n    color: blue") == ".parent .child{color:blue}"

  test "simple descendant nesting (brace)":
    check compile(".parent { .child { color: blue } }") == ".parent .child{color:blue}"

  test "& hover pseudo-class":
    check compile(".card\n  &:hover\n    color: red") == ".card:hover{color:red}"

  test "& compound class":
    check compile(".card\n  &.active\n    color: red") == ".card.active{color:red}"

  test "& child combinator":
    check compile(".parent\n  & > .item\n    margin: 0") == ".parent > .item{margin:0}"

  test "& adjacent sibling":
    check compile(".parent\n  & + .item\n    margin: 0") == ".parent + .item{margin:0}"

  test "& general sibling":
    check compile(".parent\n  & ~ .item\n    margin: 0") == ".parent ~ .item{margin:0}"

  test "deep descendant nesting":
    check compile(".x\n  .y\n    .z\n      color: red") == ".x .y .z{color:red}"

  test "parent with properties + nested child":
    check compile(".card\n  color: red\n  .child\n    color: blue") ==
      ".card{color:red}.card .child{color:blue}"

  test "multiple nested children":
    check compile(".parent\n  .a\n    color: red\n  .b\n    color: blue") ==
      ".parent .a{color:red}.parent .b{color:blue}"

  test "nested child with multiple properties":
    check compile(".parent\n  .child\n    color: red\n    font-size: 14px") ==
      ".parent .child{color:red;font-size:14px}"

  test "mixed properties and nesting":
    check compile(".card\n  padding: 1rem\n  .title\n    font-weight: bold\n  .body\n    line-height: 1.5") ==
      ".card{padding:1rem}.card .title{font-weight:bold}.card .body{line-height:1.5}"

  test "at-rule inside nested selector":
    check compile(".parent\n  @media (max-width: 768px)\n    .child\n      color: blue") ==
      ".parent{@media (max-width: 768px){.child{color:blue}}}"

  test "nesting with var() reference":
    check compile("let $col = blue\n.parent\n  .child\n    color: $col") ==
      ".parent .child{color:#0000FF}"

  test "nesting preserves selector type (id)":
    check compile("#app\n  .child\n    color: red") == "#app .child{color:red}"

  test "nesting preserves selector type (pseudo)":
    check compile(":root\n  .child\n    color: red") == ":root .child{color:red}"

  test "& multiple comma-separated":
    check compile(".card\n  &:hover, &.active\n    color: red") ==
      ".card:hover, .card.active{color:red}"

  test "nesting with !important":
    check compile(".parent\n  .child\n    color: red !important") ==
      ".parent .child{color:red !important}"

  test "comma-separated parent selectors (indent)":
    check compile(".a, .b\n  .child\n    color: red") ==
      ".a .child, .b .child{color:red}"

  test "comma-separated parent selectors (brace)":
    check compile(".a, .b {\n  .child {\n    color: red\n  }\n}") ==
      ".a .child, .b .child{color:red}"

  test "comma-separated parent with properties":
    check compile(".a, .b\n  color: red") ==
      ".a,.b{color:red}"

  test "comma-separated parent multiple nested children":
    check compile(".a, .b\n  .x\n    color: red\n  .y\n    color: blue") ==
      ".a .x, .b .x{color:red}.a .y, .b .y{color:blue}"

  test "nesting with pseudo-element":
    check compile(".card\n  &::before\n    content: \"\"") ==
      ".card::before{content:\"\"}"

  test "nesting with attribute selector":
    check compile("[data-theme] {\n  .child {\n    color: red\n  }\n}") ==
      "[data-theme] .child{color:red}"

  test "nesting with float value":
    check compile(".a\n  .b\n    opacity: .5") ==
      ".a .b{opacity:0.5}"

  test "deep nesting with & at each level":
    check compile(".a\n  &:hover\n    .b\n      &.active\n        color: red") ==
      ".a:hover .b.active{color:red}"

  test "nesting with !important on child":
    check compile(".parent\n  .child\n    color: red !important\n    font-size: 14px") ==
      ".parent .child{color:red !important;font-size:14px}"

  test "nesting with var() on child":
    check compile("let $c = red\n.parent\n  .child\n    color: $c") ==
      ".parent .child{color:#FF0000}"

  test "nesting + at-rule interleave":
    check compile(".a\n  color: red\n  @media (max-width: 768px)\n    .b\n      color: blue\n  .c\n    color: green") ==
      ".a{color:red}@media (max-width: 768px){.a .b{color:blue}}.a .c{color:green}"

  test "nesting with selector on same line as parent":
    check compile(".a { .b { color: red } .c { color: blue } }") ==
      ".a .b{color:red}.a .c{color:blue}"

  test "nesting preserves hex colors":
    check compile(".parent\n  .child\n    color: #ff0000") ==
      ".parent .child{color:#ff0000}"

  test "nesting with multiple values":
    check compile(".parent\n  .child\n    margin: 10px 20px") ==
      ".parent .child{margin:10px 20px}"

  test "nesting with empty parent (no props)":
    check compile(".wrapper\n  .content\n    padding: 1rem") ==
      ".wrapper .content{padding:1rem}"

  test "nesting id selector":
    check compile("#app\n  .sidebar\n    width: 250px") ==
      "#app .sidebar{width:250px}"

  test "nesting pseudo-class selector":
    check compile(":root\n  .child\n    color: red") ==
      ":root .child{color:red}"

  test "comma-separated children with &":
    check compile(".card\n  &:hover, &:focus\n    outline: 2px") ==
      ".card:hover, .card:focus{outline:2px}"

  test "multiple comma parents with &":
    check compile(".a, .b\n  &:hover\n    color: red") ==
      ".a:hover, .b:hover{color:red}"

suite "Phase 4: numeric edge cases":
  test "scientific notation integer":
    check compile(".a { width: 1e3; }") == ".a{width:1000}"

  test "scientific notation with unit":
    check compile(".a { width: 1e3px; }") == ".a{width:1000px}"

  test "scientific notation fractional":
    check compile(".a { letter-spacing: 1.5e-2px; }") == ".a{letter-spacing:0.015px}"

  test "scientific notation uppercase E":
    check compile(".a { z-index: 1E1; }") == ".a{z-index:10}"

  test "negative scientific notation":
    check compile(".a { margin-left: -1e2px; }") == ".a{margin-left:-100px}"

  test "scientific notation time unit":
    check compile(".a { transition-duration: 5e-1s; }") == ".a{transition-duration:0.5s}"

  test "leading plus with unit (brace)":
    check compile(".a { width: +5px; }") == ".a{width:5px}"

  test "leading plus with unit (indent)":
    check compile(".a\n  width: +5px") == ".a{width:5px}"

  test "leading plus float":
    check compile(".a { opacity: +.5; }") == ".a{opacity:0.5}"

  test "leading plus in comma list":
    check compile(".a { margin: 5px, +10px; }") == ".a{margin:5px, 10px}"

  test "leading plus plain number":
    check compile(".a { order: +2; }") == ".a{order:2}"

  test "hex color with e digit run survives":
    check compile(".a { color: #0e3f; }") == ".a{color:#0e3f}"

  test "hex color full e-run survives":
    check compile(".a { color: #1e1e1e; }") == ".a{color:#1e1e1e}"

  test "unit suffix not confused with exponent":
    check compile(".a { width: 12em; }") == ".a{width:12em}"

  test "arithmetic still uses infix plus":
    check compile("let $base = 10\n.a { width: $base + 5; }") == ".a{width:15}"

  test "integral float renders without .0":
    check compile(".a { opacity: 1.0; }") == ".a{opacity:1}"

  test "compile mixed brace/indent at-rule in selector":
    check compile(".parent {\n  @media (max-width: 768px)\n    .child\n      color: blue\n}") ==
      ".parent{@media (max-width: 768px){.child{color:blue}}}"

suite "Phase 5: mixins":
  test "basic mixin with typed parameter":
    check compile("mixin btn(color: color)\n  color: $color\n  border-radius: 4px\n.a\n  @btn(red)") ==
      ".a{color:red;border-radius:4px}"

  test "mixin without parameters":
    check compile("mixin reset()\n  margin: 0\n  padding: 0\n.a\n  @reset()") ==
      ".a{margin:0;padding:0}"

  test "mixin with eq-form body":
    check compile("mixin pad(n: number) =\n  padding: $n\n.a\n  @pad(1rem)") ==
      ".a{padding:1rem}"

  test "mixin with brace body":
    check compile("mixin btn(color: color) {\n  color: $color\n}\n.a {\n  @btn(red)\n}") ==
      ".a{color:red}"

  test "mixin with multiple parameters":
    check compile("mixin box(w: length, h: length)\n  width: $w\n  height: $h\n.a\n  @box(10px, 20px)") ==
      ".a{width:10px;height:20px}"

  test "mixin with variable argument":
    check compile("mixin btn(color: color)\n  color: $color\nlet $c = blue\n.a\n  @btn($c)") ==
      ".a{color:#0000FF}"

  test "mixin named arguments (dollar form)":
    check compile("mixin box(w: length, h: length)\n  width: $w\n  height: $h\n.a\n  @box($h = 5px, $w = 10px)") ==
      ".a{width:10px;height:5px}"

  test "mixin named arguments (bare form)":
    check compile("mixin box(w: length, h: length)\n  width: $w\n  height: $h\n.a\n  @box(h = 5px, w = 10px)") ==
      ".a{width:10px;height:5px}"

  test "mixin called multiple times":
    check compile("mixin pad(n: number)\n  padding: $n\n.a\n  @pad(1px)\n.b\n  @pad(2px)") ==
      ".a{padding:1px}.b{padding:2px}"

  test "mixin preserves parent property order":
    check compile("mixin m(c: color)\n  color: $c\n.a\n  color: red\n  @m(green)\n  background: blue") ==
      ".a{color:red;color:green;background:blue}"

  test "nested selector inside mixin (full splice)":
    check compile("mixin card\n  .title\n    font-weight: bold\n.a\n  color: red\n  @card()") ==
      ".a{color:red}.a .title{font-weight:bold}"

  test "mixin definition emits no CSS":
    check compile("mixin unused(color: color)\n  background: $color") == ""

  test "missing argument raises error":
    expect CatchableError:
      discard compile("mixin btn(color: color)\n  color: $color\n.a\n  @btn()")

suite "Phase 5: control flow inside rule bodies":
  test "if true emits contained property":
    check compile(".a\n  if true:\n    color: red") == ".a{color:red}"

  test "if false skips contained property":
    check compile(".a\n  if false:\n    color: red\n  color: blue") == ".a{color:blue}"

  test "if with variable condition":
    check compile("let $debug = true\n.a\n  if $debug:\n    outline: 1px") == ".a{outline:1px}"

  test "if else branches":
    check compile("let $m = false\n.a\n  if $m:\n    color: red\n  else:\n    color: blue") == ".a{color:blue}"

  test "for range loop emits repeated properties":
    check compile(".a\n  for $i in range(1, 3):\n    z-index: $i") == ".a{z-index:1;z-index:2;z-index:3}"

  test "for over array of objects":
    check compile("var $s = [{k: 0, v: 0}, {k: 1, v: 0.25rem}]\nfor $item in $s:\n  .p-${$item.k}\n    padding: $item.v") == ".p-0{padding:0}.p-1{padding:0.25rem}"

  test "for over inline array of objects":
    check compile("for $s in [{k: 0, v: 0}, {k: 1, v: 1rem}]:\n  .m-${$s.k}\n    margin: $s.v") == ".m-0{margin:0}.m-1{margin:1rem}"

  test "control flow with surrounding properties":
    check compile("let $on = true\n.a\n  color: red\n  if $on:\n    top: 1px\n  background: blue") == ".a{color:red;top:1px;background:blue}"

  test "while loop with counter":
    check compile("var $i = 0\n.a\n  while $i < 2\n    z-index: $i\n    $i = $i + 1") == ".a{z-index:0;z-index:1}"

  test "control flow inside mixin":
    check compile("let $v = true\nmixin m\n  if $v:\n    color: green\n.a\n  @m()") == ".a{color:green}"

  test "at-rule still parses after @ in rule bodies":
    check compile(".a\n  @media (max-width: 768px)\n    color: red") ==
      ".a{@media (max-width: 768px){color:red}}"

suite "Phase 5: fn / func aliases":
  test "fn keyword evaluates in expression position":
    check compile("fn dbl($n: int): int\n  return $n * 2\nlet $p = dbl(21)\n.a { z-index: $p }") ==
      ".a{z-index:42}"

  test "func alias works identically":
    check compile("func dbl($n: int): int\n  return $n * 2\nlet $p = dbl(21)\n.a { z-index: $p }") ==
      ".a{z-index:42}"

suite "Phase 6: modules (.bass imports)":
  let fixturesDir = currentSourcePath().parentDir / "stylesheets"

  test "import resolves and splices rules + exported vars":
    let css = compileFile(fixturesDir / "import_main.bass")
    check css == ".base{color:gray}.a{color:#0d6efd;border-radius:4px}"

  test "sourcemap segments attribute imported file correctly":
    proc compileFileVm(path: string): tuple[css: string, vm: Vm] =
      proc cb(astProgram: var Ast, p: string, resolver: FileResolver) =
        parser.parseScript(astProgram, readFile(p), p)
      var program: Ast
      parser.parseScript(program, readFile(path), path)
      let mainChunk = newChunk(path)
      var script = newScript(mainChunk)
      var module = newModule(path.extractFilename, some(path))
      let systemModule = libsystem.loadLibrary(script, newJObject(), newJObject())
      module.load(systemModule)
      script.stdpos = script.procs.high
      var gen = initCodeGen(script, module, mainChunk, manager = nil, parserCallback = cb)
      gen.genScript(program, none(string))
      let virtualMachine = newVirtualMachine(VMPreferences())
      result.css = virtualMachine.interpret(script, mainChunk).stringVal[]
      result.vm = virtualMachine

    let (css, machine) = compileFileVm(fixturesDir / "import_main.bass")
    check css.len > 0
    let segs = machine.globals.getOrDefault("__bro_sourcemap_segments").stringVal[]
    var files: seq[string]
    for record in segs.split('\x02'):
      if record.len == 0: continue
      let parts = record.split('\x03')
      if parts.len >= 4 and parts[3] notin files:
        files.add(parts[3])
    check (fixturesDir / "_vars.bass") in files
    check (fixturesDir / "import_main.bass") in files

  test "missing import raises":
    expect CatchableError:
      discard compileFile(fixturesDir / "nonexistent.bass")

proc compilePretty(code: string): string =
  ## compile() with --pretty semantics: VM emits newlines + indentation.
  var program: Ast
  parser.parseScript(program, code, "test.bass")
  let mainChunk = newChunk("test.bass")
  var script = newScript(mainChunk)
  var module = newModule("test", some("test.bass"))
  let systemModule = libsystem.loadLibrary(script, newJObject(), newJObject())
  module.load(systemModule)
  script.stdpos = script.procs.high
  var gen = initCodeGen(script, module, mainChunk)
  gen.genScript(program, none(string))
  let virtualMachine = newVirtualMachine(VMPreferences())
  virtualMachine.globals["__bro_pretty"] = initValue(true)
  result = virtualMachine.interpret(script, mainChunk).stringVal[]

suite "Phase 6: pretty output":
  test "single rule with one property":
    check compilePretty(".a { color: red; }") == ".a{\n  color:red\n}\n"

  test "multiple properties on separate lines":
    check compilePretty(".a { color: red; padding: 0; }") ==
      ".a{\n  color:red;\n  padding:0\n}\n"

  test "sibling rules separated by newline":
    check compilePretty(".a { color: red; }\n.b { color: blue; }") ==
      ".a{\n  color:red\n}\n.b{\n  color:blue\n}\n"

  test "empty rule collapses to brace pair lines":
    check compilePretty(".a {}") == ".a{\n}\n"

  test "nested rules indent via raw path":
    check compilePretty(".parent\n  color: red\n  .child\n    color: blue") ==
      ".parent{\n  color:red\n}\n.parent .child{\n  color:blue\n}\n"

  test "at-rule nesting indents inner rule":
    check compilePretty("@media (max-width: 768px) {\n  .a { color: red; }\n}") ==
      "@media (max-width: 768px){\n  .a{\n    color:red\n  }\n}\n"

  test "duplicate properties stay on separate lines (raw path)":
    check compilePretty("th { text-align: inherit; text-align: -webkit-match-parent; }") ==
      "th{\n  text-align:inherit;\n  text-align:-webkit-match-parent\n}\n"

  test "statement at-rule gets its own line":
    check compilePretty("@charset \"utf-8\";") == "@charset \"utf-8\";\n"

  test "keyframes indent their steps":
    check compilePretty("@keyframes slide { from { opacity: 0; } to { opacity: 1; } }") ==
      "@keyframes slide{\n  from{\n    opacity:0\n  }\n  to{\n    opacity:1\n  }\n}\n"

suite "Phase 6: doc-block preservation":
  test "bang banner preserved before rule (minified)":
    check compile("/*! bro v1 */\n.a { color: red }") == "/*! bro v1 */\n.a{color:red}"

  test "double-star docblock preserved with original flavor":
    check compile("/** section note */\n.b { color: blue }") == "/** section note */\n.b{color:blue}"

  test "plain block comment still stripped":
    check compile("/* gone */\n.c { color: green }") == ".c{color:green}"

  test "banner inside rule body precedes the rule":
    check compile(".a\n  /*! inner */\n  color: red") == "/*! inner */\n.a{color:red}"

  test "multiple banners keep source order":
    check compile("/*! first */\n/** second */\n.d { margin: 0 }") ==
      "/*! first */\n/** second */\n.d{margin:0}"

  test "banner between rules":
    check compile(".e { color: red }\n/*! mid */\n.f { color: blue }") ==
      ".e{color:red}/*! mid */\n.f{color:blue}"

  test "pretty mode keeps banner on its own line":
    check compilePretty("/*! b */\n.a { color: red }") == "/*! b */\n.a{\n  color:red\n}\n"

  test "pretty mode banner inside nested rule body":
    check compilePretty(".p\n  color: red\n  .c\n    color: blue") ==
      ".p{\n  color:red\n}\n.p .c{\n  color:blue\n}\n"
