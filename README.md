<p align="center">
  <img src="https://github.com/openpeep/bro/blob/main/.github/logo.png" width="170px"><br>
  😋 Bro aka NimSass - A super fast stylesheet language for cool kids<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install bro</code>
</p>

<p align="center">
  <a href="https://openpeep.github.io/bro">API reference</a><br>
  <img src="https://github.com/openpeep/bro/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeep/bro/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- [x] Extremly fast, Small executable **Only 340 kB**
- [x] Dependency free / No Virtual Machine
- [x] Works on Linux/UNIX, macOS, Windows
- [x] `Warnings` - Unused **Variables**
- [x] `Warnings` - Unused **Mixins**
- [ ] Available as a **dynlib**
- [ ] Available for **Bun JS**
- [ ] Available as a **Native NodeJS addon**
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Why BRO?
todo

## Bro 💖 Bun.js
todo

## BRO vs Sass

### Benchmark 1
<details>
  <summary>Running on a file containing <strong>393K+ lines</strong>. 2^17 instances of</summary>

```sass
button_0
  background: yellow
  
button_1
  background: yellow

button_2
  background: yellow

```

#### Bro (NimSass)

```bash
Benchmark 1: bro build big.sass --noMap
  Time (mean ± σ):     305.4 ms ±   1.6 ms    [User: 202.1 ms, System: 102.7 ms]
  Range (min … max):   302.9 ms … 306.9 ms    5 runs
```

#### SassC

```bash
Benchmark 1: sassc big.sass big.css --style=compressed
  Time (mean ± σ):      1.653 s ±  0.014 s    [User: 1.514 s, System: 0.136 s]
  Range (min … max):    1.639 s …  1.675 s    5 runs
```

#### DartSass

```bash
Benchmark 1: ./dart sass.snapshot big.sass:big.css --no-source-map --style=compressed
  Time (mean ± σ):      1.526 s ±  0.012 s    [User: 1.890 s, System: 0.107 s]
  Range (min … max):    1.512 s …  1.541 s    5 runs
```

</details>

<details>
  <summary><strong>393K * 3</strong> = <strong>1M+ lines</strong></summary>

#### Bro (NimSass)
```bash
Benchmark 1: bro build big.sass
  Time (abs ≡):        874.0 ms               [User: 650.1 ms, System: 220.7 ms]
```

#### SassC
```bash
Benchmark 1: sassc big.sass big.css
  Time (abs ≡):         5.058 s               [User: 4.698 s, System: 0.356 s]
```

#### DartSass
```bash
Benchmark 1: ./dart sass.snapshot big.sass:big.css --no-source-map
  Time (abs ≡):         4.148 s               [User: 5.203 s, System: 0.223 s]
```

</details>

- **Ubuntu 22.04 LTS**: Ryzen 5 5600g 3.9GHz × 12 / RAM 32 GB 3200MHz / SSD M.2
- **MacBook Pro mid 2015**: 2.5GHz Quad-Core i7 / RAM 16 GB 1600MHz / PCIe-based SSD
- **MacBook Air 2017**: 1.8GHz Dual-Core i5 / RAM 8 GB 1600MHz / PCIe-based SSD
- **Windows:** Need your help!

Benchmarks made with [hyperfine](https://github.com/sharkdp/hyperfine)

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeep/bro/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeep/bro/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
BRO aka NimSass | MIT license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2023 OpenPeep & Contributors &mdash; All rights reserved.
