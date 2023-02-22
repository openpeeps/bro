<p align="center">
  <img src="https://github.com/openpeep/bro/blob/main/.github/bro.png" alt="Bro aka NimSass" width="170px"><br>
  😋 Bro aka NimSass ⚡ A super fast statically typed stylesheet language for cool kids<br>👑 Written in Nim language
</p>

<p align="center">
  <a href="https://openpeep.github.io/bro">API reference</a> | <a href="#">Download</a> (not yet)<br>
  <img src="https://github.com/openpeep/bro/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeep/bro/workflows/docs/badge.svg" alt="Github Actions">
  <br><br><br>
  <strong>Bro, this is the fastest stylesheet preprocessor I've ever seen!</strong> [🐦 tweet this]
</p>

## 😍 Key Features
- [x] 🍃 Lightweight, tiny executable **650 kB**
- [x] 🐱 Dependency Free / **No Virtual Machine**
- [x] 💪 **Strong Typed Stylesheet** = Perfect **Cascading Style Sheets** 🤩
- [x] 🌍 Works on **Linux**, **macOS**, **Windows**
- [x] 👉 Friendly `Warnings` for Unused **Variables**
- [x] 👉 Friendly `Warnings` for Unused **Mixins**
- [x] 👉 Friendly `Errors` on **invalid** properties/values or typos! 
- [x] A beautiful, improved `SASS`-like Syntax [Find why Bro is better than DartSass/SassC](https://github.com/openpeep/bro#-why-bro)
- [x] 🔥 Works with **NodeJS** & **BunJS** via `NAPI`
- [x] 🎁 Built-in **CSS Minifier**
- [x] 🗺 Built-in **CSS SourceMap Generator**
- [x] 🌴 Built-in **Abstract Syntax Tree** Generator
- [x] 🎉 Built-in `HTML` Documentation Generator
- [x] 🎩 Open Source | `MIT` License
- [x] 👑 Written in **Nim language**
- [x] 😋 **Made for Cool Kids**

## ✨ Why BRO?
Because time is too precious &mdash; that's why Bro 👏

Because the official Sass implementations sucks. Zero types, no warnings, slow compilation!

Typos, invalid properties or non-standard/deprecated values? Well, from their point of view it doesn't matter,
because everything that looks like a pair of `key: value` should be just fine.

Wait, is something magic here. Don't you ever dare to miss a space between `:` and `value` because `sassc`
will simply ignore the line (no message, WTF?), same with `DartSass`, except this one is printing the "error". Oh!

&mdash; Bruh, I mean, Bro! I mean... that's why = 😋 Bro aka NimSass 👑

**Okay, okay, then why Nim?**<br>
Because [Nim is beautiful, modern, expressive](https://nim-lang.org). Nim provides performance, super fast compilation and C-like freedom.

### Bro in Console
Get it from [Downloads](#) or compile by yourself from source

```bash
😋 Bro aka NimSass - A super fast stylesheet language for cool kids!
   https://github.com/openpeep/bro

  build <style> --minify          Transpiles the given stylesheet to CSS

Development:
  watch <style> <delay>           Watch for changes and transpile the given stylesheet into CSS
  map <style>                     Generates a source map for the given stylesheet
  doc <style>                     Builds a documentation website
  ast <style> --bson              Generates Abstract Syntax Tree. Use flag to save in BSON format
  repr <ast> --minify             Convert the AST to human readable stylesheet
```

<details>
  <summary>About commands</summary>

  #### Build
  Build your awesome stylesheet to CSS.

  #### Watch
  Detect changes and build your awesome stylesheet to CSS

  #### Doc
  Generate a full Documentation website based on given stylesheet.
  Note that Bro can handle HTML snippets/previews. [Read more about HTML Snippets](#)

  #### AST
  Generate a JSON-like tree representation of your awesome stylesheet.

  #### Repr
  Generate a human-readable stylesheet from AST 

</details>

### Bro 💛 Nim
Integrate Bro in your Nim application

```bash
nimble install bro
```

### Bro 💖 BunJS & Node
Use Bro as a native addon compiled via NAPI with Node or Bun.
_Bun.js implements 90% of the APIs available in Node-API (napi). [Read more](https://github.com/oven-sh/bun#node-api-napi)_

## Examples

#### Media Queries

Bro comes with special 
```bro
body
  when isMobile:
    background-color: orange
  elif isTablet:
    background-color: salmon
  else:
    background-color: lightpink
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

Warning (11:0) CSS selector .btn has no properties [ignored]
👉 /examples/form.sass

```

## Benchmarks
- 393K+ lines / 2^17 instances of (including a new line):
```sass
button_0
  background: yellow

```

Bro style!
```bash
# Bro (NimSass) 🚀   bro build big.sass
  Time (mean ± σ):     256.1 ms ±  14.9 ms    [User: 179.0 ms, System: 77.1 ms]
  Range (min … max):   247.1 ms … 282.6 ms    5 runs

# Bro AST BSON to CSS 🔥    bro repr big.bson --minify
  Time (mean ± σ):     544.7 ms ±   3.9 ms    [User: 423.6 ms, System: 120.9 ms]
  Range (min … max):   539.3 ms … 550.2 ms    5 runs 

# Bro w/ BunJS 👍    bun bro.js
  Time (mean ± σ):     514.2 ms ±   3.1 ms    [User: 370.8 ms, System: 143.0 ms]
  Range (min … max):   510.7 ms … 517.7 ms    5 runs

# Bro w/ NodeJS 👌   node bro.js
  Time (mean ± σ):     518.6 ms ±   2.1 ms    [User: 397.7 ms, System: 120.2 ms]
  Range (min … max):   516.2 ms … 520.6 ms    5 runs
```

Original Sass implementation
```bash
# DartSass  👎    dart sass.snapshot big.sass:big.css --no-source-map
  Time (mean ± σ):      1.526 s ±  0.012 s    [User: 1.890 s, System: 0.107 s]
  Range (min … max):    1.512 s …  1.541 s    5 runs

# SassC 😅   sassc big.sass big.css
  Time (mean ± σ):      1.653 s ±  0.014 s    [User: 1.514 s, System: 0.136 s]
  Range (min … max):    1.639 s …  1.675 s    5 runs
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
  - [ ] Class Selectors [ref](https://www.w3.org/TR/selectors-3/#class-html)
  - [ ] ID Selectors [ref](https://www.w3.org/TR/selectors-3/#id-selectors)
  - [ ] Pseudo-classes [ref](https://www.w3.org/TR/selectors-3/#pseudo-classes)
  - [ ] Pseudo-elements [ref](https://www.w3.org/TR/selectors-3/#pseudo-elements)
  - [ ] Groups of Selectors [ref](https://www.w3.org/TR/selectors-3/#grouping)
  - [ ] Combinators [ref](https://www.w3.org/TR/selectors-3/#combinators)
- [x] Partials
- [x] Compile-time
  - [x] Compile-time Variables `$myvar: 12px`
  - [ ] Compile-time Constants
  - [ ] Functions
  - [ ] Conditionals (`if`, `elif`, `else`)
  - [ ] For/Loop statements `for $x in $y`
  - [ ] Magically `@when` instead of `@media`
  - [ ] Typed properties declaration
  - [ ] Warnings for unused `variables`, `functions`
  - [ ] CSS Variable Declaration using `var`
- 
- [ ] Handle single/multi line comments
- [ ] `Preview` snippets (Building docs from Stylesheets)
- [x] Command Line Interface 
  - [x] CLI `watch` for live changes
  - [x] CLI `build` sass to css
  - [ ] CLI generate source `map`
  - [x] CLI generate `ast` nodes to JSON
  - [ ] CLI build code documentation with `doc`
  - [ ] CLI convert boring sass to Bro
- [ ] Compiled Node.js / Bun.js addon via NAPI

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeep/bro/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeep/bro/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate to The Enthusiast via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
BRO aka NimSass | MIT license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2023 OpenPeep & Contributors &mdash; All rights reserved.
