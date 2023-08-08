<p align="center">
  <img src="https://github.com/openpeeps/bro/blob/main/.github/bro.png" alt="Bro aka NimSass" width="170px"><br>
  😋 Bro aka NimSass ⚡ A super fast stylesheet language for cool kids!<br>👑 Written in Nim language
</p>

<p align="center">
  <a href="https://openpeeps.github.io/bro/theindex.html">API reference</a> | <a href="#">Download</a> (not yet)<br>
  <img src="https://github.com/openpeeps/bro/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/bro/workflows/docs/badge.svg" alt="Github Actions">
  <br><br><img src="https://github.com/openpeeps/bro/blob/main/.github/bro-cli.png" width="779px">
</p>

## 😍 Key Features
- 🍃 Lightweight, tiny executable
- 🐱 Dependency Free / **No Virtual Machine**
- 💪 **Strongly Typed** = Perfect **Cascading Style Sheets** 🤩
- 🌍 Works on **Linux**, **macOS**, **Windows**
- 👉 `Warnings` => Unused **Variables**
- 👉 `Warnings` => Unused **Mixins**, **Functions**, **Empty selectors**
- 👉 `Errors` => **invalid** properties/values or typos!
- 🔖 A beautiful, improved `SASS`-like Syntax [Learn Bro in 5 minutes](https://github.com/openpeeps/bro/wiki/Learn-Bro-in-5-minutes)
- 🎁 **CSS Minifier**
- 🗺 **CSS SourceMap Generator**
- 🔄 **CSS Reload** & **Browser sync** [Setup info](https://github.com/openpeeps/bro/wiki/Index#css-reload--browser-syncing)
- 🌴 **Abstract Syntax Tree** binary serialization via **MessagePack**
- 🎉 Built-in `HTML`, `JSON` Documentation Generator
- 🔥 Works with **Node.js** & **Bun.js** via `NAPI`
- 🎆 Works in **Browser via WASM** (unstable)
- 🌍 Dynamically Linked Library
- 🎩 Open Source | [LGPLv3 license](https://github.com/openpeeps/bro/blob/main/LICENSE)
- 👑 Written in **Nim language**
- 😋 **Made for Cool Kids**

> __Warning__ Bro is still under development. Expect bugs and incomplete features.
> __Notice__ Since Bro is written in native code, anti-virus software can sometimes incorrectly flag it as a virus

## Bro CLI
Install Bro as a standalone CLI application. Get it from [Releases](#), or you might want to compile from source.

### Bro 💛 Nim
Integrate Bro in your Nim application

```nim
import bro

let stylesheet = """
$colors = [blue, yellow, orchid]
for $color in $colors:
  .bg-{$color}:
    background: $color 
"""

var
  p: Parser = parseStylesheet(stylesheet)
  c: Compiler = newCompiler(p.getStylesheet, minify = true)
echo c.getCSS # .bg-blue{background:blue}.bg-yellow{...
```

### Bro 💖 Bun & Node.js
Integrate the most powerful CSS pre-processor with Node.js/Bun.sh!

```javascript
let stylesheet = `
$colors = [blue, yellow, orchid]
for $color in $colors:
  .bg-{$color}:
    background: $color
`
const bro = require("bro.node")
bro.compile(stylesheet) // .bg-blue{background:blue}.bg-yellow{...
```

### Bro in Browser via WASM
```html
<style type="text/bro" id="stylesheet">
$colors = [blue, yellow, orchid]
for $color in $colors:
  .bg-{$color}:
    background: $color
</style>
<script src="/bro.min.js"></script>
```

```js
bro.compile('#stylesheet') // .bg-blue{background:blue}.bg-yellow{...
```

## Benchmarks
DartSass, SassC, **Bro**, **BroJS (via NAPI w/ Node & Bun)**, Sass (JS w/ Node & Bun)

1.572.876 lines of 
```sass
.btn
  background: yellow
```

```
Benchmark 1: ./dart sass.snapshot test.sass:test.css --no-source-map --style=compressed
  Time (abs ≡):         4.846 s               [User: 6.077 s, System: 0.208 s]
 
Benchmark 2: sassc test.sass test.css --style=compressed
  Time (abs ≡):         5.982 s               [User: 5.531 s, System: 0.448 s]
 
Benchmark 3: bro test.sass test.css --min
  Time (abs ≡):        658.9 ms               [User: 543.7 ms, System: 112.8 ms]
 
Benchmark 4: node bro.js
  Time (abs ≡):        942.3 ms               [User: 835.2 ms, System: 107.9 ms]
 
Benchmark 5: bun bro.js
  Time (abs ≡):        969.6 ms               [User: 775.7 ms, System: 153.5 ms]
 
Benchmark 6: node sass.js
  Time (abs ≡):        12.566 s               [User: 19.499 s, System: 1.212 s]
 
Benchmark 7: bun sass.js
  Time (abs ≡):         9.892 s               [User: 18.939 s, System: 0.938 s]
 
Summary
  'bro test.sass test.css --min' ran
    1.43 times faster than 'node bro.js'
    1.47 times faster than 'bun bro.js'
    7.35 times faster than './dart sass.snapshot test.sass:test.css --no-source-map --style=compressed'
    9.08 times faster than 'sassc test.sass test.css --style=compressed'
   15.01 times faster than 'bun sass.js'
   19.07 times faster than 'node sass.js'
```

[Check Benchmarks page](https://github.com/openpeeps/bro/wiki/Benchmarks) for more numbers

</details>

Benchmarks made with [hyperfine](https://github.com/sharkdp/hyperfine) on<br>
**Ubuntu 22.04 LTS** / Ryzen 5 5600g 3.9GHz × 12 / RAM 32 GB 3200MHz / SSD M.2


## TODO
- [x] The Interpreter (Tokens, Lexer, Parser, AST, Compiler)
- [x] CSS Selectors [ref](https://www.w3.org/TR/selectors-3/#selectors)
  - [ ] Type Selectors [ref](https://www.w3.org/TR/selectors-3/#type-selectors)
  - [ ] Universal Selectors [ref](https://www.w3.org/TR/selectors-3/#universal-selector)
  - [ ] Attribute Selectors [ref](https://www.w3.org/TR/selectors-3/#attribute-selectors)
  - [x] Class Selectors [ref](https://www.w3.org/TR/selectors-3/#class-html)
  - [x] ID Selectors [ref](https://www.w3.org/TR/selectors-3/#id-selectors)
  - [ ] Pseudo-classes [ref](https://www.w3.org/TR/selectors-3/#pseudo-classes)
  - [ ] Pseudo-elements [ref](https://www.w3.org/TR/selectors-3/#pseudo-elements)
  - [ ] Groups of Selectors [ref](https://www.w3.org/TR/selectors-3/#grouping)
  - [ ] Combinators [ref](https://www.w3.org/TR/selectors-3/#combinators)
- [x] Compile-time
  - [x] Compile-time Variables
  - [x] Arrays/Objects
    - [x] Anonymous arrays and objects
  - [ ] Compile-time Constants
  - [x] Functions
    - [x] Closures
    - [x] Overloading
    - [ ] Recursive calls
  - [ ] Mixins
  - [x] Conditionals (`if`, `elif`, `else`, and `case`)
  - [x] For/Loop statements `for $x in $y`
  - [ ] Magically `@when` instead of `@media`
  - [ ] Typed CSS properties/values
  - [x] Warnings unused `variables`, `functions`
  - [ ] CSS Variable Declaration using `var` instead of `--`
  - [ ] String/Variable concatenation using `&` and backticks
- [ ] Handle single/multi line comments
- [x] Memoization
- [ ] CSS Parser to BRO AST
- [ ] Import CSS/BASS files
  - [ ] Implement AST caching system for imported files
- [ ] `AST` Macro system (used internally to generate BASS code from CSS) 
- [x] Command Line Interface 
  - [x] CLI `watch` for live changes
  - [x] CLI `build` BASS code to css
  - [ ] CLI generate source `map`
  - [x] CLI generate `ast` nodes to binary AST via `MessagePack`
- [x] Build
  - [x] Cross-platform compilation
  - [x] Node.js/Bun.js via NAPI 
  - [ ] Browser with WASM via Emscripten

#### 0.2.x
- [ ] Convert boring SASS to BASS
- [ ] CLI build code documentation with `doc`


### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/bro/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/bro/fork)
- Create a Syntax Highlighter for your favorite code editor. 
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate to OpenPeeps via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
Bro Language [LGPLv3 license](https://github.com/openpeeps/bro/blob/main/LICENSE). Proudly made in 🇪🇺 Europe [by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.
