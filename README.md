<p align="center">
  <img src="https://github.com/openpeeps/bro/blob/main/.github/bro.png" alt="Bro aka NimSass" width="170px"><br>
  😋 Bro ⚡ A super fast stylesheet language for cool kids!<br>👑 Written in Nim language
</p>

<p align="center">
  <a href="https://openpeeps.github.io/bro/theindex.html">API reference</a> | <a href="#">Download</a> (not yet)<br>
  <img src="https://github.com/openpeeps/bro/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/bro/workflows/docs/badge.svg" alt="Github Actions">
  <br><br><img src="https://github.com/openpeeps/bro/blob/main/.github/bro-cli.png" width="779px">
</p>

## 😍 Key Features
- ⚡ Extremely fast & Highly optimized [Jump to Benchmarks](#benchmarks)
- 🍃 Lightweight, **1.5MB** tiny executable
- 🐱 Dependency Free / **No Virtual Machine**
- 💪 **Strongly Typed** = Perfect **Cascading Style Sheets** 🤩
- 🌍 Works on **Linux**, **macOS**, **Windows**
- 🔖 A beautiful, improved `SASS`-like Syntax [Learn Bro in 5 minutes](https://github.com/openpeeps/bro/wiki/Learn-Bro-in-5-minutes)
- 📚 Standard Library (`strings`, `arrays`, `objects`, `math`, `regex`, `os`) [Check the manual](https://github.com/openpeeps/bro/wiki/Standard-Library)
- 👋 Human readable Syntax => **Developer friendly**
  - `var` & `const`
  - `[]` Arrays
  - `{}` Objects
  - `if` & `case` Conditionals  
  - `for` Loop Statements
  - `fn` Functions & `mix` Mixins
    - Overloading + Closures + Forward declaration
  - `CSS` to `BASS` AST with `include some.css`
  - `BASS` imports using `import std/[strings, math]`
  - **JSON/YAML stream** to BASS using `json("some.json")`, `yaml("some.yml")`
- 👏 Built-in CSS Optimization (Autoprefixer, Minifier, CSS Alphabetize & Deduplication)
- 🗺 **CSS SourceMap Generator**
- 🔄 **CSS Reload** & **Browser sync** [Setup info](https://github.com/openpeeps/bro/wiki/Index#css-reload--browser-syncing)
- 🌴 **Abstract Syntax Tree** binary serialization
- 🎉 Built-in `HTML`, `JSON` Documentation Generator
- 🔥 Works with **Node.js** & **Bun.js** via `NAPI`
- 🎆 Works in **Browser via WASM** (unstable)
- 🌍 Dynamically Linked Library
- 👉 `Warnings` => Unused **Variables**
- 👉 `Warnings` => Unused **Mixins**, **Functions**, **Empty selectors**
- 👉 `Errors` => **invalid** properties/values or typos!
- 🏳 Recommended Extension `.bass`
- 🎩 Open Source | [LGPLv3 license](https://github.com/openpeeps/bro/blob/main/LICENSE)
- 👑 Written in **Nim language**
- 😋 **Made for Cool Kids**

> [!WARNING]  
> Bro is still under development. Expect bugs and incomplete features.


> [!NOTE]
> Since Bro is written in native code, anti-virus software can sometimes incorrectly flag it as a virus

## Bro CLI
Install Bro as a standalone CLI application. Get it from [Releases](#) or build it from source using Nim & Nimble.


### Bro 💛 Nim
Integrate Bro in your Nim application

```nim
import bro

let stylesheet = """
$colors = [blue, yellow, orchid]
for $color in $colors:
  .bg-{$color}
    background: $color 
"""

var
  p: Parser = parseStylesheet(stylesheet)
  c: Compiler = newCompiler(p.getStylesheet, minify = true)
echo c.getCSS # .bg-blue{background:blue}.bg-yellow{...
```

### Bro 💖 Bun & Node.js
Integrate the most powerful CSS pre-processor in your Node.js/Bun app. Bro is available as a native addon module

```javascript
let stylesheet = `
$colors = [blue, yellow, orchid]
for $color in $colors:
  .bg-{$color}
    background: $color
`
const bro = require("bro.node")
bro.compile(stylesheet) // .bg-blue{background:blue}.bg-yellow{...
```

### Bro in Browser via Wasm
Build complex real-time web-apps using Bro + WebAssembly
```html
<style type="text/bro" id="stylesheet">
$colors = [blue, yellow, orchid]
for $color in $colors:
  .bg-{$color}
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
  Time (abs ≡):         4.925 s               [User: 6.060 s, System: 0.263 s]
 
Benchmark 2: bro test.sass test.css --min
  Time (abs ≡):        441.7 ms               [User: 422.3 ms, System: 19.9 ms]
 
Benchmark 3: sassc test.sass test.css --style=compressed
  Time (abs ≡):         5.757 s               [User: 5.346 s, System: 0.400 s]
 
Benchmark 4: bun bro.js
  Time (abs ≡):        679.0 ms               [User: 616.0 ms, System: 24.0 ms]
 
Benchmark 5: node bro.js
  Time (abs ≡):        653.7 ms               [User: 625.8 ms, System: 32.3 ms]
 
Benchmark 6: node sass.js
  Time (abs ≡):        12.783 s               [User: 19.640 s, System: 1.185 s]
 
Benchmark 7: bun sass.js
  Time (abs ≡):        10.485 s               [User: 20.422 s, System: 1.030 s]
 
Summary
  'bro test.sass test.css --min' ran
    1.48 times faster than 'node bro.js'
    1.54 times faster than 'bun bro.js'
   11.15 times faster than './dart sass.snapshot test.sass:test.css --no-source-map --style=compressed'
   13.03 times faster than 'sassc test.sass test.css --style=compressed'
   23.74 times faster than 'bun sass.js'
   28.94 times faster than 'node sass.js'
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
  - [x] Variables
  - [x] Arrays/Objects
    - [x] Anonymous arrays and objects
  - [x] Constants
  - [x] Functions
    - [x] Closures
    - [x] Overloading
    - [ ] Recursive calls
  - [ ] Mixins
  - [x] Conditionals (`if`, `elif`, `else`, and `case`)
  - [x] For/Loop statements `for $x in $y`
  - [ ] Typed CSS properties/values
  - [x] Warnings unused `variables`, `functions`
  - [ ] CSS Variable Declaration using `var` instead of `--`
  - [ ] String/Variable concatenation using `&` and backticks
- [ ] Handle single/multi line comments
- [x] Memoization
- [x] Import CSS/BASS files
  - [ ] Implement AST caching system
- [x] Command Line Interface 
  - [x] CLI `watch` for live changes
  - [x] CLI `build` BASS code to CSS
  - [ ] CLI generate source `map`
  - [x] CLI `ast` command for generating binary AST
- [x] Build
  - [x] Cross-platform compilation
  - [x] Node.js/Bun.js via NAPI 
  - [ ] Browser with WASM via Emscripten

#### 0.2.x
- [ ] Convert boring SASS to BASS
- [ ] CLI `doc` command for generating documentation website


### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/bro/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/bro/fork)
- Create a Syntax Highlighter for your favorite code editor. 
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate to OpenPeeps via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
Bro Language [LGPLv3 license](https://github.com/openpeeps/bro/blob/main/LICENSE). Proudly made in 🇪🇺 Europe [by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.
