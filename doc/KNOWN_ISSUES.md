# Known issues

[← back to README](../README.md)

The design works in a demo, but it has real bugs. Every one below was found by reading the code and the Quartus reports, and the first four are reproduced in simulation.

**1. Words 128–199 of the dictionary never appear.**
In `target_words`, `word_index = actual_word * 8 + letter_number` is declared 10 bits wide, but 200 words × 8 slots needs 11 bits. Any word index ≥ 128 wraps around onto words 0–71. A round still shows 49 words, but roughly a third of them are a different word than the randomizer picked, and duplicates can appear. *Fix:* widen `word_index` and `next_index` to 11 bits. (`tb_target_words`)

**2. A correctly typed 8-letter word scores as wrong.**
Words get exactly 8 slots, so an 8-letter word like `resistor` or `inductor` fills them all and has no terminating space. When the player correctly presses space, the comparator still expects the last letter. It scores the word as ended early: +1 char error and +1 word error. *Fix:* use 9 slots per word, or treat `letter_index == 8` as end of word. (`tb_comparator`)

**3. A round lasts 16 seconds, but WPM assumes 15.**
`countdown_timer` loads 15, counts 15 → 0, and asserts `timer_expired` one tick *after* reaching 0. WPM is therefore overstated by 1/15 (about 7%). *Fix:* expire when the value goes 1 → 0, or load 14. (`tb_timer`)

**4. The first word's length is stale after the first round.**
On `start_new_test`, the comparator resets `word_index <= 0` and calls `recompute_word_len()` in the same cycle. Because of the non-blocking assignment, the task still sees the *old* `word_index`. If the first word of a later round is cut short, its missing-letter penalty uses the length of the word the previous round stopped on. Pressing `KEY0` between rounds hides this today, but it will show up once issue 5 is fixed. *Fix:* compute the length from index 0 explicitly on reset. (`tb_comparator`)

**5. Back-to-back rounds don't work cleanly.**
The [game-flow diagram](diagrams/game_flow.png) intends `KEY0` between rounds. Skipping it, or following it, both cause problems:
- *Without `KEY0`:* after a round, the post-game flag stays set until `KEY2`, so the arbiter keeps the pixel bus pointed at the (idle) stats drawer. Pressing `KEY1` loads a new word list into the scorer but draws none of it on screen. The next round then shows the old words while scoring against the new ones.
- *With `KEY0`:* the clear FSM only runs while `nextScreen = 0`, so it only ever clears the game screen. Drawers write only lit pixels (see [Drawing text](../README.md#drawing-text)), so round 2's result digits are drawn on top of round 1's.

*Fix:* have the drawers write background pixels too (`color = lit ? FG : BG`), so every glyph fully overwrites the one before it. Also clear the post-game flag when `KEY1` is pressed.

**6. Timing is not met (Fmax 17.6 MHz against a 50 MHz clock).**
Quartus inferred **25 combinational dividers**:

- 12 in `stats_calculator`
- 8 in `main.v`, splitting error counts into digits
- 2 in each glyph drawer
- 1 in the randomizer

`stats_calculator` chains `correct × 100 / total` straight into `/10` and `%10` in one cycle, which is the likely critical path. There is also no `.sdc` file. Separately, `comparator` and `word_randomizer` assign non-constant values inside their asynchronous reset branches. Quartus turns those into latches (11 combinational loops) and treats `KEY[0]` as a clock. *Fix:* compute the stats over several cycles with a small sequential divider or double-dabble; make reset values constant; add `create_clock` and `derive_pll_clocks` in an SDC.

**7. The comparator is far larger than it needs to be.**
Reading `words_flat[bit_index +: 5]` with a runtime index, inside an 8-iteration loop that runs every cycle, builds about 4,700 ALMs of muxes. *Fix:* keep the target list in a block RAM and read one letter per keystroke. The scorer only ever needs the current letter.

Smaller issues: the clear table's accuracy-box `y` is written as `9'd1125`, which overflows 9 bits. The red in-game numbers on the game screen are part of the background art, not live values; the live values are on the HEX displays.

## Reproducing

```
cd test && make
```

Issues 1–4 show up as `XFAIL` lines. When a fix lands, the matching test turns into `XPASS`; then the known-bug flag in the testbench can be cleared.
