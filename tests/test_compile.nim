import ../src/bro/engine/vancodegen
import unittest
import std/options
import pkg/openparser/json

import ../src/bro/engine/parser

import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value]

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

suite "compilation tests":
  test "compile simple class selector":
    let css = compile(".foo { color: red; }")
    check css == ".foo{color:red;}"

  test "compile class with multiple properties":
    let css = compile("""
  .card {
    color: blue;
    font-size: 16px;
  }
  """)
    check css == ".card{color:blue;font-size:16px;}"

  test "compile id selector":
    let css = compile("#header { width: 100px; }")
    check css == "#header{width:100px;}"

  test "compile pseudo selector":
    let css = compile(":root { font-size: 16px; }")
    check css == ":root{font-size:16px;}"

  test "compile element selector":
    let css = compile("h1 { color: red; }")
    check css == "h1{color:red;}"

  test "compile multiple selectors comma separated":
    let css = compile("h1, btn { color: red; }")
    check css == "h1,btn{color:red;}"

  test "compile element selector followed by rules on same line":
    let css = compile("a, btn:hover { padding-top: 10px; }.p-0 { padding: 0; }")
    check css == "a,btn:hover{padding-top:10px;}.p-0{padding:0;}"

  test "compile attribute selector":
    let css = compile("[data-bs-theme=dark] { color: red; }")
    check css == "[data-bs-theme=dark]{color:red;}"

  test "compile attribute selector with quoted value":
    let css = compile("[data-bs-theme=\"dark\"] { color: red; }")
    check css == "[data-bs-theme=\"dark\"]{color:red;}"

  test "compile attribute selector on class":
    let css = compile(".dropdown[data-bs-popper] { padding: 0; }")
    check css == ".dropdown[data-bs-popper]{padding:0;}"

  test "compile attribute selector with caret operator":
    let css = compile("a[href^=\"http\"] { color: blue; }")
    check css == "a[href^=\"http\"]{color:blue;}"

  test "compile attribute selector with tilde operator":
    let css = compile("[data-x~=foo] { display: block; }")
    check css == "[data-x~=foo]{display:block;}"

  test "compile attribute selector with dollar operator":
    let css = compile("[data-x$=\"suffix\"] { display: none; }")
    check css == "[data-x$=\"suffix\"]{display:none;}"

  test "compile attribute selector with pipe operator":
    let css = compile("[data-x|=en] { width: 10px; }")
    check css == "[data-x|=en]{width:10px;}"

  test "compile element with attribute and pseudo":
    let css = compile("input[type=\"checkbox\"]:checked { color: green; }")
    check css == "input[type=\"checkbox\"]:checked{color:green;}"

  test "compile minified css without spaces":
    let css = compile("body{color:red}.foo{padding:0}")
    check css == "body{color:red;}.foo{padding:0;}"

  test "compile hex color starting with digit":
    let css = compile(".foo{color:#0d6efd}")
    check css == ".foo{color:#0d6efd;}"

  test "compile leading-dot float":
    let css = compile(".foo{margin-top:.125rem}")
    check css == ".foo{margin-top:0.125rem;}"

  test "compile descendant selector after attribute":
    let css = compile("[data-bs-theme=\"dark\"] .dropdown-menu { color: red; }")
    check css == "[data-bs-theme=\"dark\"] .dropdown-menu{color:red;}"

  test "compile attribute with comma-separated selectors":
    let css = compile("a[href^=\"http\"], [data-x^=\"y\"] { color: blue; }")
    check css == "a[href^=\"http\"],[data-x^=\"y\"]{color:blue;}"

  test "compile adjacent sibling combinator":
    let css = compile(".btn-check:checked+.btn { color: red; }")
    check css == ".btn-check:checked+.btn{color:red;}"

  test "compile child combinator":
    let css = compile(".parent>.child { color: red; }")
    check css == ".parent>.child{color:red;}"

  test "compile var() css function":
    let css = compile(".btn { color: var(--bs-btn-hover-color); }")
    check css == ".btn{color:var(--bs-btn-hover-color);}"

  test "compile css variable declarations":
    let css = compile(":root { --bs-blue: #0d6efd; --bs-breakpoint-md: 768px; }")
    check css == ":root{--bs-blue:#0d6efd;--bs-breakpoint-md:768px;}"

  test "compile pseudo-element":
    let css = compile(".foo::before { display: block; }")
    check css == ".foo::before{display:block;}"

  test "compile important modifier":
    let css = compile(".foo { color: red !important; }")
    check css == ".foo{color:red !important;}"

  test "compile descendant element selectors":
    let css = compile("""
  ol ol,
  ul ul,
  ol ul,
  ul ol {
    margin-bottom: 0;
  }
  """)
    check css == "ol ol,ul ul,ol ul,ul ol{margin-bottom:0;}"

  test "compile nested element selector in at-rule":
    let css = compile("@media (min-width: 768px) { ol li { color: blue; } }")
    check css == "@media (min-width: 768px){ol li{color:blue;}}"

  test "compile is() functional pseudo":
    let css = compile(".table :is(thead,tbody,tfoot)>tr>th,td { padding: .5rem; }")
    check css == ".table :is(thead,tbody,tfoot)>tr>th,td{padding:0.5rem;}"

  test "compile not() functional pseudo":
    let css = compile(".visually-hidden:not(caption) { position: absolute; }")
    check css == ".visually-hidden:not(caption){position:absolute;}"

  test "compile nth-child functional pseudo":
    let css = compile(".x:nth-child(2n+1) { color: red; }")
    check css == ".x:nth-child(2n+1){color:red;}"

  test "compile compound class selector":
    let css = compile(".offcanvas.offcanvas-start { color: red; }")
    check css == ".offcanvas.offcanvas-start{color:red;}"

  test "compile duplicate property keys (vendor fallback)":
    let css = compile("th { text-align: inherit; text-align: -webkit-match-parent; }")
    check css == "th{text-align:inherit;text-align:-webkit-match-parent;}"

  test "compile negative space-separated values":
    let css = compile(".x { margin: -0.375rem -0.75rem; }")
    check css == ".x{margin:-0.375rem -0.75rem;}"

  test "compile nested comma-separated values":
    let css = compile(".x { background-position: right 0.75rem center, center right 2.25rem; }")
    check css == ".x{background-position:right 0.75rem center, center right 2.25rem;}"

  test "compile indent based class selector":
    let css = compile("""
  .foo
    color: red
    font-size: 14px
  """)
    check css == ".foo{color:red;font-size:14px;}"

  test "compile nested selector":
    let css = compile("""
  .parent
    .child
      color: blue
  """)
    check css == ".parent{}.child{color:blue;}"

  test "compile class with pseudo selector":
    let css = compile("""
  .btn:hover
    color: blue
  """)
    check css == ".btn:hover{color:blue;}"

  test "compile unit values":
    let css = compile(".box { width: 100px; }")
    check css == ".box{width:100px;}"

  test "compile float values":
    let css = compile(".a { size: 1.5; }")
    check css == ".a{size:1.5;}"

  test "compile string value":
    let css = compile(".c { font-family: \"Arial\"; }")
    check css == ".c{font-family:\"Arial\";}"

  test "compile multiple values":
    let css = compile(".pad { margin: 10px 20px; }")
    check css == ".pad{margin:10px 20px;}"

  test "compile multiple nested selectors":
    let css = compile("""
  .a
    .b
      color: red
    .c
      color: blue
  """)
    check css == ".a{}.b{color:red;}.c{color:blue;}"

  test "compile deeply nested selectors":
    let css = compile("""
  .x
    .y
      .z
        color: red
  """)
    check css == ".x{}.y{}.z{color:red;}"

  test "compile css custom property":
    let css = compile("""
  :root {
    --primary: #333;
  }
  """)
    check css == ":root{--primary:#333;}"

  test "compile hex color value":
    let css = compile(".foo { color: #ff0000; }")
    check css == ".foo{color:#ff0000;}"

  test "compile empty selector":
    let css = compile(".empty { }")
    check css == ".empty{}"

  test "compile multiple top-level selectors":
    let css = compile("""
  .a { color: red; }
  .b { color: blue; }
  """)
    check css == ".a{color:red;}.b{color:blue;}"

  test "compile indent based with braces":
    let css = compile("""
  .foo {
    color: red
  }
  """)
    check css == ".foo{color:red;}"

  test "compile variable declaration and usage":
    let css = compile("""
  var $primary = red
  .foo { color: $primary; }
  """)
    check css == ".foo{color:#FF0000;}"

  test "compile let declaration":
    let css = compile("""
  let $size = 16px
  .foo { font-size: $size; }
  """)
    check css == ".foo{font-size:16px;}"

  test "compile multiple variable usage":
    let css = compile("""
  var $a = 10
  var $b = 20
  .foo { width: $a; height: $b; }
  """)
    check css == ".foo{width:10;height:20;}"

  test "compile variable reference in selector block":
    let css = compile("""
  let $col = blue
  .foo
    color: $col
    background: $col
  """)
    check css == ".foo{color:#0000FF;background:#0000FF;}"

  test "compile arithmetic in value":
    let css = compile("""
  let $base = 10
  .foo { width: $base + 5; }
  """)
    check css == ".foo{width:15;}"

  test "compile string variable":
    let css = compile("""
  let $name = "hello"
  .foo { content: $name; }
  """)
    check css == ".foo{content:hello;}"

  test "compile @media query":
    let css = compile("""
  @media (max-width: 768px)
    .foo
      color: red
  """)
    check css == "@media (max-width: 768px){.foo{color:red;}}"

  test "compile @supports":
    let css = compile("""
  @supports (display: grid)
    .foo { color: red; }
  """)
    check css == "@supports (display: grid){.foo{color:red;}}"

  test "compile @font-face":
    let css = compile("""
  @font-face {
    font-family: "Custom";
    src: url("custom.woff2");
  }
  """)
    check css == "@font-face{font-family:\"Custom\";src:url(\"custom.woff2\");}"

  test "compile @keyframes":
    let css = compile("""
  @keyframes slide
    from
      opacity: 0
    to
      opacity: 1
  """)
    check css == "@keyframes slide{from{opacity:0;}to{opacity:1;}}"

  test "compile @import":
    let css = compile("@import url(\"style.css\");")
    check css == "@import url(style.css);"

  test "compile @media with comma-separated selectors":
    let css = compile("""
  @media (min-width: 480px)
    .foo, .bar
      color: blue
  """)
    check css == "@media (min-width: 480px){.foo,.bar{color:blue;}}"

  test "compile nested @media inside selector":
    let css = compile("""
  .parent
    @media (max-width: 768px)
      .child
        color: blue
  """)
    check css == ".parent{@media (max-width: 768px){.child{color:blue;}}}"

  test "compile @media brace-delimited":
    let css = compile("@media (max-width: 768px) { .foo { color: red; } }")
    check css == "@media (max-width: 768px){.foo{color:red;}}"

  test "compile @supports simple":
    let css = compile("@supports (display: grid) { .foo { color: red; } }")
    check css == "@supports (display: grid){.foo{color:red;}}"

  test "compile @supports with not":
    let css = compile("@supports not (display: grid) { .foo { color: red; } }")
    check css == "@supports not (display: grid){.foo{color:red;}}"

  test "compile @layer unnamed":
    let css = compile("""
  @layer
    .foo
      color: red
  """)
    check css == "@layer{.foo{color:red;}}"

  test "compile @layer multiple named":
    let css = compile("@layer base, theme;")
    check css == "@layer base, theme;"

  test "compile @font-face with single descriptor":
    let css = compile("@font-face { font-family: \"Custom\"; }")
    check css == "@font-face{font-family:\"Custom\";}"

  test "compile @keyframes brace-delimited":
    let css = compile("@keyframes slide { from { opacity: 0; } to { opacity: 1; } }")
    check css == "@keyframes slide{from{opacity:0;}to{opacity:1;}}"

  test "compile @keyframes with percentage":
    let css = compile("""
  @keyframes slide
    0%
      opacity: 0
    100%
      opacity: 1
  """)
    check css == "@keyframes slide{0%{opacity:0;}100%{opacity:1;}}"

  test "compile @charset":
    let css = compile("@charset \"utf-8\";")
    check css == "@charset utf-8;"

  test "compile @namespace":
    let css = compile("@namespace url(\"http://www.w3.org/1999/xhtml\");")
    check css == "@namespace url(http://www.w3.org/1999/xhtml);"

  test "compile property after @media":
    let css = compile("""
  @media (max-width: 768px)
    .foo
      color: red
  .bar
    color: blue
  """)
    check css == "@media (max-width: 768px){.foo{color:red;}}.bar{color:blue;}"
