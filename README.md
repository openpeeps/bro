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
- [x] **Strong Typed Stylesheet** = Perfect **Cascading Style Sheets**
- [x] 🌍 Works on **Linux**, **macOS**, **Windows**
- [x] 👉 Friendly `Warnings` for Unused **Variables**
- [x] 👉 Friendly `Warnings` for Unused **Mixins**
- [x] A beautiful, improved `SASS`-like Syntax [Find why is different than DartSass](#why-different)
- [x] 🔥 Works with **NodeJS** & **BunJS** via `NAPI`
- [x] 🎁 Built-in **CSS Minifier**
- [x] 🗺 Built-in **CSS SourceMap Generator**
- [x] 🌴 Built-in **Abstract Syntax Tree** Generator
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

### Bro 💛 Nim
Integrate Bro in your Nim application

```bash
nimble install bro
```

### Bro 💖 BunJS & Node
Use Bro as a native addon compiled via NAPI with Node or Bun.
_Bun.js implements 90% of the APIs available in Node-API (napi). [Read more](https://github.com/oven-sh/bun#node-api-napi)_


## Benchmarks
- 393K+ lines / 2^17 instances of (including a new line):
```sass
button_0
  background: yellow

```

```bash
# Bro (NimSass) 🚀   bro build big.sass
  Time (mean ± σ):     256.1 ms ±  14.9 ms    [User: 179.0 ms, System: 77.1 ms]
  Range (min … max):   247.1 ms … 282.6 ms    5 runs

# Bro w/ BunJS 👍    bun bro.js
  Time (mean ± σ):     514.2 ms ±   3.1 ms    [User: 370.8 ms, System: 143.0 ms]
  Range (min … max):   510.7 ms … 517.7 ms    5 runs

# Bro w/ NodeJS 👌   node bro.js
  Time (mean ± σ):     518.6 ms ±   2.1 ms    [User: 397.7 ms, System: 120.2 ms]
  Range (min … max):   516.2 ms … 520.6 ms    5 runs

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


## Friendly Warnings
**This is part of "No need to run 1000 npm packages"** to write some CSS.

Example
```
Warning (5:0): Declared and not used $primary-color
 /examples/main.sass

Warning (1:0): Declared and not used $paddin-gSize
 /examples/forms/form.sass

Warning (2:0): Declared and not used $font-stack
 /examples/forms/form.sass

Warning (6:0): Declared and not used $file-border-color
 /examples/forms/form.sass

Warning (5:0): Declared and not used $file-radius
 /examples/forms/form.sass

Error (21899:2): Unknown pseudo-class `focusa`
  /examples/main.sass
```

## TODO
- [x] Partials
- [ ] Resolver
- [x] Compile-Time Variables using `$`
- [ ] Functions
- [ ] Conditionals
- [ ] For/Loop statements
- [ ] Typed properties
- [ ] Warnings for unused `variables`, `functions`
- [ ] CSS Variable Declaration using `var`
- [ ] `Preview` snippets (Docum)
- [x] Command Line Interface 
  - [x] CLI `watch` for live changes
  - [x] CLI `build` sass to css
  - [ ] CLI generate source `map`
  - [x] CLI generate `ast` nodes to JSON
  - [ ] CLI build code documentation with `doc`
- [ ] Compiled Node.js / Bun.js addon via NAPI

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeep/bro/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeep/bro/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate to The Enthusiast via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
BRO aka NimSass | MIT license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2023 OpenPeep & Contributors &mdash; All rights reserved.
