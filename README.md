# HarambeType

**A Monkeytype-style typing test built in hardware on a DE1-SoC FPGA. There is no CPU and no soft core: keyboard decoding, word generation, scoring and text rendering are all Verilog state machines.**

![Verilog](https://img.shields.io/badge/RTL-Verilog--2001-blue)
![Board](https://img.shields.io/badge/board-DE1--SoC-orange)
![FPGA](https://img.shields.io/badge/FPGA-Cyclone%20V%205CSEMA5F31C6-red)
![Tool](https://img.shields.io/badge/Quartus%20Prime-18.1%20Lite-lightgrey)
![Sim](https://img.shields.io/badge/sim-Icarus%20Verilog-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

<p align="center">
  <a href="doc/media/demo.mp4"><img src="doc/media/demo.gif" width="560" alt="Typing on the board: the target words are on top and the typed text appears in the box below"></a><br>
  <sub>Typing on the board during development. Click for the full video.</sub>
</p>

<p align="center">
  <img src="doc/media/gameplay.jpg" width="400" alt="In-game screen with a wrong word drawn in red">
  &nbsp;
  <img src="doc/media/results.jpg" width="360" alt="Results screen showing accuracy, word errors, character errors and WPM">
  <br><sub>Left: typing a round. The mistyped word <code>PROP</code> is drawn in red. Right: the results screen.</sub>
</p>

---

## What it is

A hardware version of [Monkeytype](https://monkeytype.com), built as the final project for a second-year digital systems course at the University of Toronto. A PS/2 keyboard plugs into the board and a VGA monitor shows the game.

- **KEY1** picks a fresh random set of words from a 200-word dictionary and draws about 175 characters of them in the top box.
- **KEY2** starts a 15-second round. Every keystroke is drawn in the typing box, white if correct and red if wrong. The board's 7-segment displays show the timer and live error counts.
- When time runs out, the display switches to a second framebuffer. That screen shows **accuracy, total word errors, total character errors, and words per minute**.

## Results

Quartus Prime 18.1 Lite, device 5CSEMA5F31C6 ([full reports](project/reports)):

| Resource | Used | Available | % |
|---|---:|---:|---:|
| Logic (ALMs) | 7,900 | 32,070 | 25% |
| Registers | 3,090 | | |
| Block memory bits | 1,852,759 | 4,065,280 | 46% |
| M10K RAM blocks | 229 | 397 | 58% |
| DSP blocks | 9 | 87 | 10% |
| PLLs | 1 | 6 | 17% |

Where the logic went:

| Module | ALMs | Notes |
|---|---:|---|
| `comparator` | 4,713 | **60% of the design**: a runtime index into a 1,600-bit bus becomes a huge mux |
| `done_list` | 1,160 | 320-letter target list held in 2,143 flip-flops, not RAM |
| `stats_calculator` | 574 | 12 combinational `/` and `%` operators |
| `target_words` (+ randomizer) | 447 | 200-word dictionary folded into LUT logic |
| `vga_adapter` | 192 | two full-screen framebuffers in 226 M10Ks |

**Timing: not met.** The Timing Analyzer reports **Fmax = 17.6 MHz** against the 50 MHz board clock (−36.8 ns worst setup slack), and the project has no `.sdc` file. The design still works on the board, most likely because the slow paths (stats math, digit conversion) only change once per keystroke and settle long before they're used. That's luck, not design. See [Known issues](#known-issues).

## Hardware and controls

| | |
|---|---|
| Board | Terasic DE1-SoC |
| FPGA | Intel Cyclone V SE `5CSEMA5F31C6` |
| Display | VGA, 640×480 @ 60 Hz, 3-bit color (1 bit per channel) |
| Input | PS/2 keyboard (letters a–z and space) |
| Clock | 50 MHz `CLOCK_50`; a PLL makes the 25 MHz pixel clock |

| Control | Action |
|---|---|
| `KEY0` | Reset. Clears the text boxes. |
| `KEY1` | Shuffle and draw a new set of target words |
| `KEY2` | Start the 15-second round |
| `HEX1:HEX0` | Seconds remaining |
| `HEX3:HEX2` | Character errors |
| `HEX5:HEX4` | Word errors |

To play a round: `KEY0` → `KEY1` → `KEY2` → type.

## How it works

### Architecture

<p align="center"><img src="doc/media/architecture.svg" alt="Block diagram"></p>

`main.v` is the control plane: the game-phase flags (preload, typing, post-game), the preload FSM, the text cursor, the box-clear FSM, and the arbiter that picks which drawer owns the pixel bus. Every other module does one job behind a `valid`/`busy`/`done` handshake.

### Design diagrams

Hand-drawn while designing the system. The final RTL differs in two details: `done_list` holds 40 words (a 1,600-bit bus), not 49, and a glyph takes about 400 cycles to draw, not 64.

<table>
<tr>
<td align="center" width="62%"><a href="doc/diagrams/top_level.png"><img src="doc/diagrams/top_level.png" alt="Hand-drawn top-level block diagram"></a><br><sub>Top level: every module and the buses between them</sub></td>
<td align="center" width="38%"><a href="doc/diagrams/game_flow.png"><img src="doc/diagrams/game_flow.png" alt="Game flow state diagram"></a><br><sub>Game flow: RESET → IDLE → shuffle → preload → typing → results, with KEY0 returning to RESET</sub></td>
</tr>
</table>

Per-subsystem diagrams:

- [Keyboard input path](doc/diagrams/input_path.png)
- [Word source (randomizer → target words)](doc/diagrams/word_source.png)
- [Scoring (done_list → comparator → stats)](doc/diagrams/scoring_path.png)
- [Rendering (drawers → arbiter → clear FSM → VGA)](doc/diagrams/render_path.png)

### Keyboard input

`ps2_receiver` synchronizes the PS/2 lines into the 50 MHz domain and shifts in each 11-bit frame. `scancode_to_fontIndex` drops break (`F0 xx`) and extended (`E0 xx`) sequences, and maps a–z to 0–25 and space to 26. Those are the same numbers as the glyph positions in the font ROM, so a key's code is used directly as a font address. `main.v` accepts a key only while a round is running and nothing is drawing or clearing.

### Picking words

On `KEY1`, `word_randomizer` steps an 8-bit LFSR (taps 8, 6, 5, 4), seeded from a free-running counter so the time of the button press changes the shuffle. A 200-bit `used` vector rejects repeats. `target_words` keeps the first 49 picks from its 200-word dictionary. A preload FSM then streams them one character at a time, drawing each on screen and copying it into `done_list` for the scorer. It stops after at least 175 characters, at a word boundary.

### Scoring

`comparator` walks a `(word, letter)` pointer through the target list on every keystroke:

| Typed | Expected | Result |
|---|---|---|
| letter | same letter | advance |
| letter | different letter | +1 char error, word marked wrong, advance |
| letter | end of word | +1 char error (extra letter), word marked wrong |
| space | end of word | next word; +1 word error if marked wrong |
| space | still mid-word | +1 char error per skipped letter, +1 word error, next word |

If `char_errors` rose on a keystroke, that glyph is drawn red; otherwise white. When the timer expires, `stats_calculator` computes `WPM = correct × 4 / 5` (15-second round) and `accuracy = correct × 100 / total`, then registers them as BCD digits.

### Drawing text

There is no text mode. Three drawers (`preload_`, `char_` and `stats_to_pixel_draw`) share one FSM, `IDLE → SETUP → READ → DRAW → NEXT_PX → NEXT_ROW → DONE`. Each one reads an 8×8 glyph from a block-RAM font ROM and writes every lit pixel as a 2×2 block (3×3 for the result digits). Only lit pixels are written, so whatever is already in the framebuffer shows through behind each glyph.

### Two framebuffers

Titles, labels and borders aren't drawn by logic. They're baked into the framebuffers' initial contents as `.mif` files. `vga_adapter` was modified to hold **two** 640×480 framebuffers, and one `nextScreen` bit picks which is drawn into and shown, so switching to the results screen is a single register flip. That only fits because the design drops to 3-bit color: one 9-bit framebuffer is 68% of the chip's block RAM, while two 3-bit ones are 45%.

<p align="center">
  <img src="doc/media/framebuffer_game.png" width="400" alt="Game-screen framebuffer initial contents">
  &nbsp;
  <img src="doc/media/framebuffer_results.png" width="400" alt="Results-screen framebuffer initial contents">
  <br><sub>Initial framebuffer contents, rendered from the .mif files.</sub>
</p>

A box-clear FSM sweeps the text boxes back to black on reset, and clears the typing box when the cursor wraps.

## Repository layout

```
src/                     final RTL (what the .sof was built from)
  main.v                 top level: control FSMs, arbiter, clear FSM, HEX
  Input/                 ps2_receiver, scancode_to_fontIndex
  Game/                  comparator, done_list, stats_calculator, timer, word_randomizer
  Memory/                target_words (dictionary), font_mem, num_mem (ROM wrappers)
  Drawing/               preload / char / stats glyph drawers
  VGA_Adapter/           course VGA adapter, modified for two framebuffers
project/                 Quartus project, .mif images, prebuilt bitstream, reports
test/                    self-checking Icarus Verilog testbenches + Makefile
doc/KNOWN_ISSUES.md      bug list with root causes and fixes
doc/media/               demo video, photos, block diagram, rendered framebuffers
doc/diagrams/            hand-drawn design diagrams (top level, game flow, subsystems)
archive/                 milestone 1–3 development snapshots (source only)
```

## Build and run

**Flash the prebuilt bitstream:** open the Quartus Programmer, select `project/harambetype.sof`, and program the DE1-SoC over USB-Blaster.

**Rebuild:** open `project/main.qpf` in Quartus Prime 18.1 Lite or newer and compile.

## Simulation

Self-checking testbenches run on free tools with `cd test && make`:

| Test | Checks | Status |
|---|---|---|
| `tb_input` | Real PS/2 frames through the receiver and decoder; break, extended and unmapped keys are filtered | PASS |
| `tb_comparator` | Scoring for perfect typing, typos, short words and extra letters | PASS, 2 XFAIL |
| `tb_target_words` | Each streamed word is the one the randomizer picked | XFAIL |
| `tb_timer` | A round lasts 15 s | XFAIL |

XFAIL means the test checks the correct behaviour and fails because of a [known bug](#known-issues).

## Known issues

It works in a demo, but it has real bugs, found by reading the code and the Quartus reports. Full root causes and fixes are in **[doc/KNOWN_ISSUES.md](doc/KNOWN_ISSUES.md)**.

| # | Issue | Cause | Test |
|---|---|---|---|
| 1 | Dictionary words 128–199 never appear | 10-bit address for an 11-bit range | `tb_target_words` |
| 2 | A correct 8-letter word scores as wrong | no slot left for the word terminator | `tb_comparator` |
| 3 | Rounds last 16 s, but WPM assumes 15 | timer expires one tick after 0 | `tb_timer` |
| 4 | Stale first-word length in later rounds | non-blocking assignment ordering | `tb_comparator` |
| 5 | Round 2 results draw over round 1 | results screen is never cleared | — |
| 6 | Fmax 17.6 MHz vs 50 MHz clock | 25 combinational dividers, no SDC | — |
| 7 | `comparator` uses 60% of the logic | runtime-indexed 1,600-bit bus | — |

## Design evolution

- **Milestone 1:** PS/2 keyboard → letter on screen. A single glyph drawer and the stock course VGA adapter.
- **Milestone 2:** target words, the `done_list`/`comparator` scoring core, and an on-screen countdown. 9-bit color with one framebuffer used 86% of the RAM blocks.
- **Milestone 3 (final):** a second framebuffer for the results screen, which forced the drop to 3-bit color. Also added: randomized word order, per-character red/white feedback, WPM and accuracy, and HEX displays for live stats.

The full history is in [`archive/`](archive).

## Credits and license

Built by [@Synx162](https://github.com/Synx162) and [Philip Mugambi](https://www.linkedin.com/in/philip-mugambi-m/) as a two-person course project.

- `vga_adapter`, `vga_controller`, `vga_address_translator` and `vga_pll` are based on the University of Toronto ECE VGA adapter. `vga_adapter` was modified here to hold two framebuffers.
- The PS/2 receiver's synchronizer and shift register follow the course PS/2 demo.

MIT licensed. See [LICENSE](LICENSE).
