# HarambeType

A Monkeytype-style typing test we built in Verilog on a DE1-SoC FPGA. There's no processor anywhere in it. The keyboard decoding, word shuffling, scoring and text drawing are all done in hardware.

![Verilog](https://img.shields.io/badge/RTL-Verilog--2001-blue)
![Board](https://img.shields.io/badge/board-DE1--SoC-orange)
![FPGA](https://img.shields.io/badge/FPGA-Cyclone%20V%205CSEMA5F31C6-red)
![Tool](https://img.shields.io/badge/Quartus%20Prime-18.1%20Lite-lightgrey)
![Sim](https://img.shields.io/badge/sim-Icarus%20Verilog-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

<p align="center">
  <a href="doc/media/demo.mp4"><img src="doc/media/demo.gif" width="560" alt="Typing on the board: the target words are on top and the typed text appears in the box below"></a><br>
  <sub>Typing on the board during development (click for the full video)</sub>
</p>

<p align="center">
  <img src="doc/media/gameplay.jpg" width="400" alt="In-game screen with a wrong word drawn in red">
  &nbsp;
  <img src="doc/media/results.jpg" width="360" alt="Results screen showing accuracy, word errors, character errors and WPM">
  <br><sub>Left: mid-round, with the mistyped word <code>PROP</code> in red. Right: the results screen.</sub>
</p>

---

## What it is

This was our final project for ECE241 (Digital Systems) at the University of Toronto. You plug a PS/2 keyboard into the board and the game runs on a VGA monitor.

Press KEY1 and the board shuffles a 200-word list and prints about 175 characters of random words at the top of the screen. Press KEY2 to start a 15-second round. Everything you type shows up in the box underneath, in white if it's right and red if it's wrong, and the 7-segment displays count down the time and track your errors. When the timer hits zero the screen switches to a results page with your accuracy, word errors, character errors and WPM.

## Results

Compiled in Quartus Prime 18.1 Lite for the 5CSEMA5F31C6 (the [full reports](project/reports) are in the repo):

| Resource | Used | Available | % |
|---|---:|---:|---:|
| Logic (ALMs) | 7,900 | 32,070 | 25% |
| Registers | 3,090 | | |
| Block memory bits | 1,852,759 | 4,065,280 | 46% |
| M10K RAM blocks | 229 | 397 | 58% |
| DSP blocks | 9 | 87 | 10% |
| PLLs | 1 | 6 | 17% |

Most of the logic ended up in two modules:

| Module | ALMs | Why |
|---|---:|---|
| `comparator` | 4,713 | About 60% of the whole design. It reads the target list through a 1,600-bit bus with a runtime index, which turns into a giant mux. |
| `done_list` | 1,160 | Holds the 320 target letters in flip-flops instead of RAM |
| `stats_calculator` | 574 | 12 divide and modulo operators |
| `target_words` + randomizer | 447 | The 200-word dictionary ends up in LUTs |
| `vga_adapter` | 192 | Two full-screen framebuffers (226 M10Ks) |

The design does not meet timing. Quartus reports a max frequency of 17.6 MHz, but the board clock is 50 MHz. We also never wrote an `.sdc` file, which is where you tell Quartus what clock speed you're targeting. It still runs fine on the board, probably because the slow paths are the stats math and digit conversion, and those inputs only change once per keypress. We go into this more in [Known issues](#known-issues).

## Hardware and controls

| | |
|---|---|
| Board | Terasic DE1-SoC |
| FPGA | Intel Cyclone V SE `5CSEMA5F31C6` |
| Display | VGA, 640×480 @ 60 Hz, 3-bit color |
| Input | PS/2 keyboard (a–z and space) |
| Clock | 50 MHz `CLOCK_50`, with a PLL for the 25 MHz pixel clock |

| Control | What it does |
|---|---|
| `KEY0` | Reset and clear the text boxes |
| `KEY1` | Shuffle and draw a new set of words |
| `KEY2` | Start the 15-second round |
| `HEX1:HEX0` | Seconds left |
| `HEX3:HEX2` | Character errors |
| `HEX5:HEX4` | Word errors |

To play: `KEY0`, then `KEY1`, then `KEY2`, then type.

## How it works

<p align="center"><img src="doc/media/architecture.svg" alt="Block diagram"></p>

`main.v` is the top level. It holds the game-state flags (preload, typing, results), the preload FSM, the text cursor, the logic that clears the text boxes, and an arbiter that decides which drawer gets to write to the screen. Each of the other modules handles one job and talks to the top level with `valid`, `busy` and `done` signals.

### Our design diagrams

We drew these while planning the project. The final code changed a little from them: `done_list` ended up holding 40 words instead of 49, and drawing a letter takes about 400 clock cycles rather than 64.

<table>
<tr>
<td align="center" width="62%"><a href="doc/diagrams/top_level.png"><img src="doc/diagrams/top_level.png" alt="Hand-drawn top-level block diagram"></a><br><sub>Top level: every module and the buses between them</sub></td>
<td align="center" width="38%"><a href="doc/diagrams/game_flow.png"><img src="doc/diagrams/game_flow.png" alt="Game flow state diagram"></a><br><sub>Game flow, from reset to the results screen</sub></td>
</tr>
</table>

There are also diagrams for each part: [keyboard input](doc/diagrams/input_path.png), [word source](doc/diagrams/word_source.png), [scoring](doc/diagrams/scoring_path.png) and [rendering](doc/diagrams/render_path.png).

### Keyboard input

The PS/2 clock and data lines come from the keyboard, which isn't synced to our 50 MHz clock, so `ps2_receiver` runs both through two flip-flops first and then shifts in each 11-bit frame. A keyboard sends a code when you press a key and `F0` plus that code when you let go, so `scancode_to_fontIndex` throws away the release codes and the extended (`E0`) keys. Letters become 0–25 and space becomes 26. We picked those numbers on purpose, because they line up with where each letter sits in the font ROM.

### Picking words

When you press KEY1, `word_randomizer` runs an 8-bit LFSR. It's seeded from a counter that never stops, so the exact moment you press the button changes the order you get. A 200-bit "used" register stops any word from being picked twice, and `target_words` keeps the first 49 picks. A small FSM then sends those words out one letter at a time. Each letter gets drawn on screen and also saved into `done_list` so the scorer knows what you're supposed to type. It stops once about 175 characters are on screen, at the end of a word.

### Scoring

`comparator` keeps track of which word and letter you're on and checks every key you press:

| You type | It expects | What happens |
|---|---|---|
| a letter | that letter | move on |
| a letter | a different letter | +1 char error, word marked wrong, move on |
| a letter | the end of the word | +1 char error (extra letter), word marked wrong |
| space | the end of the word | next word, +1 word error if the word was marked wrong |
| space | more letters | +1 char error for each letter you skipped, +1 word error, next word |

If the character error count went up on a keypress, that letter gets drawn in red. When time runs out, `stats_calculator` works out `WPM = correct × 4 / 5` (since a round is a quarter of a minute) and `accuracy = correct × 100 / total`, then converts both to decimal digits for the results screen.

### Drawing text

There's no text mode on the board, so every letter is drawn one pixel at a time. We have three drawers, for the target words, what you type and the final stats, and they all use the same FSM: `IDLE → SETUP → READ → DRAW → NEXT_PX → NEXT_ROW → DONE`. Each one reads an 8×8 letter out of a font ROM and draws every lit pixel as a 2×2 block (3×3 for the big numbers on the results screen). They only draw the lit pixels and skip the background ones.

### Two screens

We didn't draw the titles, labels or boxes with logic. They're saved as images in `.mif` files that get loaded into the framebuffers when the board is programmed. We changed the course's `vga_adapter` to hold two full framebuffers, one for the game and one for the results, and a single bit picks which one is on screen. That made switching to the results page instant.

Fitting two full screens meant dropping from 9-bit to 3-bit color. A single 9-bit screen would have used 68% of the chip's block RAM on its own, while two 3-bit screens use 45%.

<p align="center">
  <img src="doc/media/framebuffer_game.png" width="400" alt="Game-screen framebuffer initial contents">
  &nbsp;
  <img src="doc/media/framebuffer_results.png" width="400" alt="Results-screen framebuffer initial contents">
  <br><sub>What's in each framebuffer at power-on</sub>
</p>

There's also a clear FSM that wipes the text boxes back to black on reset, and wipes the typing box when you fill it up.

## Repository layout

```
src/                     final Verilog (what the bitstream was built from)
  main.v                 top level, game FSMs, arbiter, box clearing, HEX displays
  Input/                 ps2_receiver, scancode_to_fontIndex
  Game/                  comparator, done_list, stats_calculator, timer, word_randomizer
  Memory/                target_words (the word list), font_mem, num_mem
  Drawing/               the three letter/number drawers
  VGA_Adapter/           course VGA adapter, changed to hold two framebuffers
project/                 Quartus project, .mif images, prebuilt .sof, reports
test/                    Icarus Verilog testbenches and a Makefile
doc/KNOWN_ISSUES.md      every bug we know about and how to fix it
doc/media/               demo video, photos, block diagram, framebuffer images
doc/diagrams/            our hand-drawn design diagrams
archive/                 code from milestones 1–3
```

## Build and run

To just play it, open the Quartus Programmer, pick `project/harambetype.sof` and program the board over USB-Blaster.

To rebuild it, open `project/main.qpf` in Quartus Prime 18.1 Lite (or newer) and compile.

## Simulation

There are four testbenches in `test/` that check their own results. You only need Icarus Verilog to run them:

```
cd test && make
```

| Test | What it checks | Result |
|---|---|---|
| `tb_input` | Sends real PS/2 frames through the receiver and decoder, and checks that key releases, extended keys and unmapped keys get ignored | PASS |
| `tb_comparator` | Scoring for perfect typing, typos, short words and extra letters | PASS, 2 XFAIL |
| `tb_target_words` | Every word that comes out is the one the randomizer picked | XFAIL |
| `tb_timer` | A round lasts 15 seconds | XFAIL |

XFAIL means the test is checking for the right behaviour and fails because of one of the bugs below.

## Known issues

It works in a demo, but we've found real bugs since. Here's the short version. [doc/KNOWN_ISSUES.md](doc/KNOWN_ISSUES.md) explains each one and how to fix it.

| # | Problem | Cause | Test |
|---|---|---|---|
| 1 | Words 128–199 in the list never show up | address is 10 bits but needs 11 | `tb_target_words` |
| 2 | Typing an 8-letter word correctly still counts as wrong | no room left to mark the end of the word | `tb_comparator` |
| 3 | Rounds actually last 16 s, but WPM assumes 15 | timer ends one tick late | `tb_timer` |
| 4 | Wrong word length used at the start of later rounds | ordering of non-blocking assignments | `tb_comparator` |
| 5 | Round 2's results get drawn on top of round 1's | results screen is never cleared | — |
| 6 | Max frequency is 17.6 MHz, the clock is 50 MHz | 25 single-cycle dividers, no timing constraints | — |
| 7 | `comparator` uses 60% of all the logic | runtime index into a 1,600-bit bus | — |

## How it evolved

- **Milestone 1:** got a key press to show up as a letter on screen, using one drawer and the stock course VGA adapter.
- **Milestone 2:** added the target words, the scoring logic and an on-screen countdown. At 9-bit color, the one screen used 86% of the RAM blocks.
- **Milestone 3 (final):** added a second screen for results, which is why we went down to 3-bit color. Also added random word order, red/white feedback per letter, WPM and accuracy, and the HEX displays.

The code from each milestone is in [`archive/`](archive).

## Credits and license

Built by [@Synx162](https://github.com/Synx162) and [Philip Mugambi](https://www.linkedin.com/in/philip-mugambi-m/).

The VGA adapter files (`vga_adapter`, `vga_controller`, `vga_address_translator`, `vga_pll`) are based on the University of Toronto ECE VGA adapter, which we modified to hold two framebuffers. The PS/2 receiver's synchronizer and shift register follow the course PS/2 demo.

MIT licensed. See [LICENSE](LICENSE).
