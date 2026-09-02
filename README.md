<p align="center">
  <img src="https://github.com/openpeeps/bro/blob/main/.github/bro.png" alt="Bro" width="170px"><br>
  Bro — Compiled CSS Preprocessor
</p>

<p align="center">
  <a href="https://openpeeps.github.io/bro/theindex.html">API Reference</a> |
  <a href="https://bro.openpeeps.dev/">Documentation</a><br>
  <img src="https://github.com/openpeeps/bro/workflows/test/badge.svg" alt="Github Actions"> <img src="https://github.com/openpeeps/bro/workflows/docs/badge.svg" alt="Github Actions">
</p>

## Overview

Bro transpiles BASS files to standard CSS. It is written in Nim and designed for fast compilation, a typed system that catches errors early, and syntax that stays close to CSS while adding variables, nesting, mixins, control flow, and modules.

BASS files use the `.bass` extension and compile to `.css`.

## Features

- Compiled to native code with a fast VM and ahead-of-time code generation
- Typed system for CSS values (`color`, `length`, `number`, etc.) with compile-time checks
- Familiar CSS syntax with indentation or brace blocks
- Variables (`let`, `var`, `const`) with optional type annotations and export (`*`)
- Nesting with parent selector `&`, combinators, and comma-separated selectors
- Reusable mixins with typed parameters and named arguments
- Control flow (`if` / `elif` / `else`, `for`, `while`, `case` / `of`) and functions (`fn` / `func`)
- Module imports (`import "./vars.bass"`) and package imports (`pkg/`)
- Modern CSS passthrough: custom properties, `var()`, `calc()`, `color-mix()`, gradients, and at-rules
- Source maps, bundling, and pretty-printed output

## Quick Start

### Installation

Requires Nim >= 2.0.0 (https://nim-lang.org/install.html).

```sh
nimble install bro
```

### Compile

```sh
bro c style.bass -o style.css        # compile to CSS (minified by default)
bro c style.bass --pretty -o style.css  # pretty-printed output
bro c style.bass --watch             # recompile on change
bro -h                               # all options
```

Source maps are supported with `--sourceMap`.

## Syntax Showcase

All examples are minified by default. Add `--pretty` for formatted output.

### 1. Variables

```bass
let $primary = #0d6efd
let $radius = 4px

.card
  color: $primary
  border-radius: $radius
```
```css
.card{color:#0d6efd;border-radius:4px}
```
Variables use `let` / `var` / `const`, support interpolation (`$primary`), and are checked against CSS property types — the compiler rejects mismatches such as `width: red`.

### 2. Nesting

```bass
.card
  color: gray
  &:hover
    color: black
  .title
    font-weight: bold
```
```css
.card{color:gray}.card:hover{color:black}.card .title{font-weight:bold}
```
Supports `&` for pseudo-classes, combinators (`& > .item`, `& + .item`), and comma-separated parents. Brace syntax works as well: `.card { &:hover { color: black } }`.

### 3. Mixins

```bass
mixin btn(color: color)
  color: $color
  border-radius: 4px

.a
  @btn(red)
```
```css
.a{color:red;border-radius:4px}
```
Mixins accept typed parameters, support named arguments (`@box($h = 5px, $w = 10px)`), and can contain nested selectors.

### 4. Control Flow and Code Generation

```bass
for $i in range(1, 3):
  .p-${$i}
    z-index: $i
```
```css
.p-1{z-index:1}.p-2{z-index:2}.p-3{z-index:3}
```
Other constructs:

```bass
let $debug = true
.a
  if $debug:
    outline: 1px
  else:
    outline: none
```

`for` also iterates over arrays of objects (`for $s in [{k:0,v:0}, {k:1,v:0.25rem}]`), `while`, and `case` / `of` are available.

### 5. Imports

```bass
// _vars.bass
let $accent* = #0d6efd
let $radius* = 4px

// main.bass
import "./_vars.bass"
.a
  color: $accent
  border-radius: $radius
```
```css
.a{color:#0d6efd;border-radius:4px}
```
Export with `*`, import relative files or packages.

### 6. Functions

```bass
fn dbl($n: int): int
  return $n * 2

let $p = dbl(21)
.a { z-index: $p }
```
```css
.a{z-index:42}
```
`func` is an alias for `fn`. Functions support overloading and forward declarations.

## Documentation

- [API Reference](https://openpeeps.github.io/bro/theindex.html)
- [Official Documentation](https://bro.openpeeps.dev/)

## Contributing

- Report a bug: [Create an issue](https://github.com/openpeeps/bro/issues)
- Contribute code: [Fork the repository](https://github.com/openpeeps/bro/fork)
- Questions or feedback: open an issue or discussion.

## License

Bro is released under the `LGPL-3.0-or-later` license. Made by Humans from OpenPeeps.<br>
Copyright &copy; 2026 OpenPeeps & Contributors — All rights reserved.
