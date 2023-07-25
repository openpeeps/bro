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
- 💪 **Strong Typed** = Perfect **Cascading Style Sheets** 🤩
- 🌍 Works on **Linux**, **macOS**, **Windows**
- 👉 `Warnings` => Unused **Variables**
- 👉 `Warnings` => Unused **Mixins**, **Functions**, **Empty selectors**
- 👉 `Errors` => **invalid** properties/values or typos!
- 🔖 A beautiful, improved `SASS`-like Syntax [Learn Bro in 5 minutes](https://github.com/openpeeps/bro/wiki/Learn-Bro-in-5-minutes)
- 🎁 **CSS Minifier**
- 🗺 **CSS SourceMap Generator**
- 🔄 **CSS Reload** & **Browser sync** [Setup info](https://github.com/openpeeps/bro/wiki/Index#css-reload--browser-syncing)
- 🌴 **Abstract Syntax Tree** binary serialization via **MessagePack**
- 🎉 Built-in `HTML` Documentation Generator
- 🔥 Works with **NodeJS** & **BunJS** via `NAPI`
- 🎩 Open Source | [LGPLv3 license](https://github.com/openpeeps/bro/blob/main/LICENSE)
- 👑 Written in **Nim language**
- 😋 **Made for Cool Kids**

> __Warning__ Bro is still under development. Expect bugs and incomplete features.


## Bro CLI
```
😋 Bro aka NimSass - A super fast stylesheet language for cool kids!
   https://github.com/openpeeps/bro

   <style> --minify --map --gzip          Compiles a stylesheet to CSS

Development:
  watch <style> <delay>                   Watch for changes and compile
  map <style>                             Generates a source map
  ast <style> --gzip                      Generates a packed AST
  repr <ast> --minify --gzip              Compiles packed AST to CSS

Documentation:
  doc <style>                             Builds a documentation website

```

### Bro 💛 Nim
Integrate Bro in your Nim application

```bash
nimble install bro
```

### Bro 💖 BunJS & Node
Use Bro as a native addon compiled via NAPI with Node or Bun. [Get it from releases](#) or compile by yourself from source.
_Bun.js implements 90% of the APIs available in Node-API (napi). [Read more](https://github.com/oven-sh/bun#node-api-napi)_

```javascript
const {compile} = require("./bro.node")
compile("./awesome.sass")
```

## Friendly Warnings
**This is part of "No need to run 1000 npm packages"** to write some CSS.

1. **Perfect for beginners!**
```
Error (18:17) Invalid value font-style: bold 
      Available values:
            normal
            italic
            oblique
 👉 /examples/dummies.sass
```

2. Typos? No worries!
```
Error (21899:2): Unknown pseudo-class `focusa`
👉 /examples/main.sass
```

3. Keep your stylesheets clean!
```
Warning (5:0): Declared and not used $primary-color
👉 /examples/main.sass

Warning (6:0): Declared and not used $file-border-color
👉 /examples/form.sass

Warning (11:0) CSS selector .btn has no properties
👉 /examples/form.sass

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

### BRO vs BRO Binary AST

Obviously, the `repr` command will run faster, since the entire AST is built 
```
Benchmark 1: bro big.sass
  Time (abs ≡):         1.084 s               [User: 0.762 s, System: 0.317 s]
 
Benchmark 2: bro repr big.ast
  Time (abs ≡):        793.0 ms               [User: 548.7 ms, System: 240.3 ms]

```

</details>

Benchmarks made with [hyperfine](https://github.com/sharkdp/hyperfine) on<br>
**Ubuntu 22.04 LTS** / Ryzen 5 5600g 3.9GHz × 12 / RAM 32 GB 3200MHz / SSD M.2

## TODO
- [x] Tokenizier
- [x] Selectors [ref](https://www.w3.org/TR/selectors-3/#selectors)
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
  - [x] Compile-time Variables `$myvar = 12px`
  - [x] Arrays/Objects
    - [ ] Anonymous arrays and objects
  - [ ] Compile-time Constants
  - [x] Functions
    - [x] Closures
    - [x] Overloading 
  - [x] Conditionals (`if`, `elif`, `else`, and `case`)
  - [x] For/Loop statements `for $x in $y`
  - [ ] Magically `@when` instead of `@media`
  - [ ] Typed properties declaration
  - [x] Warnings unused `variables`, `functions`
  - [ ] CSS Variable Declaration using `var` instead of `--`
  - [ ] String/Variable concatenation using `&` and backticks
- [ ] Handle single/multi line comments
- [ ] `Preview` snippets (Building docs from Stylesheets)
- [x] Command Line Interface 
  - [x] CLI `watch` for live changes
  - [x] CLI `build` sass to css
  - [ ] CLI generate source `map`
  - [x] CLI generate `ast` nodes to binary AST via `MessagePack`
  - [ ] CLI build code documentation with `doc`
  - [ ] CLI convert boring sass to Bro
- [x] Compiled Node.js / Bun.js addon via NAPI [Check @openpeeps/denim](https://github.com/openpeeps/denim)

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/bro/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/bro/fork)
- Create a Syntax Highlighter for your favorite code editor. 
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate to OpenPeeps via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
BRO aka NimSass | [LGPLv3 license](https://github.com/openpeeps/bro/blob/main/LICENSE). Proudly made in 🇪🇺 Europe [by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.
