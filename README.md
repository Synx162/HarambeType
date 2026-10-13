# HarambeType

A Monkeytype-style typing test in Verilog on a DE1-SoC FPGA. No CPU or soft core: keyboard decoding, word shuffling, scoring and text rendering are all hardware.

![Verilog](https://img.shields.io/badge/RTL-Verilog--2001-blue)
![Board](https://img.shields.io/badge/board-DE1--SoC-orange)
![FPGA](https://img.shields.io/badge/FPGA-Cyclone%20V%205CSEMA5F31C6-red)
![Tool](https://img.shields.io/badge/Quartus%20Prime-18.1%20Lite-lightgrey)
![Sim](https://img.shields.io/badge/sim-Icarus%20Verilog-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

<p align="center">
  <a href="doc/media/demo.mp4"><img src="doc/media/demo.gif" width="560" alt="Typing on the board"></a><br>
  <sub>Demo on the board (click for full video)</sub>
</p>

<p align="center">
  <img src="doc/media/gameplay.jpg" width="400" alt="In-game screen with a wrong word in red">
  &nbsp;
  <img src="doc/media/results.jpg" width="360" alt="Results screen">
  <br><sub>A round in progress (wrong word in red) and the results screen</sub>
</p>

## Overview

- **KEY1** shuffles a 200-word list and draws ~175 characters of target words.
- **KEY2** starts a 15-second round. Typed letters are drawn white if correct, red if wrong. The HEX displays show time left and error counts.
- When time runs out, the display switches to a results screen with accuracy, word errors, character errors and WPM.

## Results

Quartus Prime 18.1 Lite, 5CSEMA5F31C6 ([reports](project/reports)):

| Resource | Used | % |
|---|---:|---:|
| ALMs | 7,900 / 32,070 | 25% |
| Registers | 3,090 | |
| Block memory | 1.85 / 4.07 Mbit | 46% |
| M10K blocks | 229 / 397 | 58% |
| DSP blocks | 9 / 87 | 10% |

| Module | ALMs | Notes |
|---|---:|---|
| `comparator` | 4,713 | 60% of the design; runtime-indexed 1,600-bit bus |
| `done_list` | 1,160 | target list held in registers |
| `stats_calculator` | 574 | 12 combinational dividers |
| `target_words` + randomizer | 447 | 200-word dictionary in LUTs |
| `vga_adapter` | 192 | two framebuffers, 226 M10Ks |

Timing is not met: Fmax is 17.6 MHz against the 50 MHz clock, and there's no `.sdc` constraints file. It runs correctly on the board because the slowest paths (stats and digit conversion) only change once per keypress. See [Known issues](#known-issues).

## Hardware and controls

| | |
|---|---|
| Board / FPGA | DE1-SoC, Cyclone V `5CSEMA5F31C6` |
| Display | VGA 640×480 @ 60 Hz, 3-bit color |
| Input | PS/2 keyboard (a–z, space) |
| Clock | 50 MHz, PLL to 25 MHz pixel clock |

| Control | Action |
|---|---|
| `KEY0` | Reset |
| `KEY1` | New words |
| `KEY2` | Start round |
| `HEX1:0` / `HEX3:2` / `HEX5:4` | Time left / char errors / word errors |

## How it works

<p align="center"><img src="doc/media/architecture.svg" alt="Block diagram"></p>

`main.v` holds the game-state flags, the preload FSM, the text cursor, the box-clear FSM and the arbiter that picks which drawer writes to the screen. Other modules communicate with it through `valid` / `busy` / `done` handshakes.

<table>
<tr>
<td align="center" width="62%"><a href="doc/diagrams/top_level.png"><img src="doc/diagrams/top_level.png" alt="Top-level diagram"></a><br><sub>Top-level design</sub></td>
<td align="center" width="38%"><a href="doc/diagrams/game_flow.png"><img src="doc/diagrams/game_flow.png" alt="Game flow"></a><br><sub>Game flow</sub></td>
</tr>
</table>

Subsystem diagrams: [input](doc/diagrams/input_path.png) · [word source](doc/diagrams/word_source.png) · [scoring](doc/diagrams/scoring_path.png) · [rendering](doc/diagrams/render_path.png)

**Keyboard input.** `ps2_receiver` passes the PS/2 lines through 2-FF synchronizers and shifts in 11-bit frames. `scancode_to_fontIndex` drops release (`F0`) and extended (`E0`) codes and maps a–z to 0–25 and space to 26, which are also the glyph positions in the font ROM.

**Word selection.** `word_randomizer` runs an 8-bit LFSR seeded from a free-running counter, with a 200-bit used-word vector to prevent repeats. `target_words` keeps the first 49 picks. The preload FSM streams them one character at a time to the screen and into `done_list`, stopping at a word boundary after 175 characters.

**Scoring.** `comparator` tracks the current word and letter on each keypress:

| Typed | Expected | Result |
|---|---|---|
| letter | same letter | advance |
| letter | different letter | +1 char error, word marked wrong |
| letter | end of word | +1 char error (extra letter) |
| space | end of word | next word, +1 word error if marked wrong |
| space | more letters | +1 char error per skipped letter, +1 word error |

A letter is drawn red if the char error count went up on that keypress. At the end of the round `stats_calculator` computes `WPM = correct × 4 / 5` and `accuracy = correct × 100 / total` and converts them to BCD.

**Drawing.** Three drawers (target text, typed text, stats) share one FSM: `IDLE → SETUP → READ → DRAW → NEXT_PX → NEXT_ROW → DONE`. Each reads an 8×8 glyph from ROM and writes lit pixels scaled 2× (3× for result digits).

**Two framebuffers.** Titles, labels and borders are preloaded from `.mif` images. `vga_adapter` was modified to hold two 640×480 framebuffers, one for the game and one for results, selected by a single bit. Dropping to 3-bit color made both fit in 45% of block RAM; one 9-bit framebuffer alone would take 68%.

<p align="center">
  <img src="doc/media/framebuffer_game.png" width="400" alt="Game framebuffer">
  &nbsp;
  <img src="doc/media/framebuffer_results.png" width="400" alt="Results framebuffer">
</p>

## Repository layout

```
src/            final Verilog
project/        Quartus project, .mif files, prebuilt .sof, reports
test/           Icarus Verilog testbenches + Makefile
doc/            diagrams, media, KNOWN_ISSUES.md
archive/        milestone 1–3 code
```

## Build and run

- **Program:** load `project/harambetype.sof` in the Quartus Programmer.
- **Rebuild:** open `project/main.qpf` in Quartus Prime 18.1+ and compile.

## Simulation

```
cd test && make
```

| Test | Checks | Result |
|---|---|---|
| `tb_input` | PS/2 frames decode correctly; releases, extended and unmapped keys are ignored | PASS |
| `tb_comparator` | Perfect typing, typos, short words, extra letters | PASS, 2 XFAIL |
| `tb_target_words` | Each word shown is the one the randomizer picked | XFAIL |
| `tb_timer` | Round lasts 15 s | XFAIL |

XFAIL = the test checks correct behaviour and fails due to a known bug.

## Known issues

Details and fixes in [doc/KNOWN_ISSUES.md](doc/KNOWN_ISSUES.md).

| # | Issue | Cause |
|---|---|---|
| 1 | Words 128–199 never appear | 10-bit address, needs 11 |
| 2 | Correct 8-letter words count as wrong | no slot for the end-of-word marker |
| 3 | Rounds last 16 s, WPM assumes 15 | timer expires one tick late |
| 4 | Wrong first-word length in later rounds | non-blocking assignment ordering |
| 5 | Round 2 results overlap round 1 | results screen never cleared |
| 6 | Fmax 17.6 MHz vs 50 MHz | 25 single-cycle dividers, no SDC |
| 7 | `comparator` is 60% of the logic | runtime index into a 1,600-bit bus |

## Development

- **Milestone 1:** keypress to letter on screen.
- **Milestone 2:** target words, scoring and on-screen timer (9-bit color, 86% of RAM blocks).
- **Milestone 3:** results screen, 3-bit color, random word order, red/white feedback, WPM and accuracy, HEX displays.

## Credits

Built by [@Synx162](https://github.com/Synx162) and [Philip Mugambi](https://www.linkedin.com/in/philip-mugambi-m/).

VGA adapter files are based on the University of Toronto ECE VGA adapter (modified for two framebuffers). The PS/2 receiver's synchronizer follows the course PS/2 demo. MIT licensed, see [LICENSE](LICENSE).
