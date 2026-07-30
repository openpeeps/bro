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
    check css == ".c{font-family:Arial;}"

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
    check css == "@font-face{font-family:Custom;src:url(custom.woff2);}"

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
    check css == "@font-face{font-family:Custom;}"

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
