# Known issues

[← README](../README.md)

Issues 1–4 are reproduced by the testbenches in `test/` (`cd test && make`, they show as `XFAIL`).

### 1. Words 128–199 never appear
`target_words` computes `word_index = actual_word * 8 + letter_number` into a 10-bit wire. The last address is 1,599, which needs 11 bits, so word numbers ≥ 128 wrap onto words 0–71. About a third of each round's words aren't the ones the randomizer picked, and repeats can appear.
**Fix:** widen `word_index` and `next_index` to 11 bits.

### 2. Correct 8-letter words count as wrong
Each word has 8 slots, and shorter words end with a space code. An 8-letter word (`resistor`, `inductor`) fills every slot, so when space is pressed the comparator is still expecting the last letter and scores +1 char error and +1 word error.
**Fix:** use 9 slots per word, or treat letter index 8 as end of word.

### 3. Rounds last 16 s, WPM assumes 15
`countdown_timer` counts 15 → 0 and asserts `timer_expired` one second after reaching 0. WPM reads about 7% high.
**Fix:** expire on the 1 → 0 transition, or start at 14.

### 4. Wrong first-word length in later rounds
On a new round the comparator sets `word_index <= 0` and calls `recompute_word_len()` in the same cycle, so the task still sees the old `word_index`. This only affects the penalty for cutting the first word short. A KEY0 reset hides it.
**Fix:** compute the length for index 0 directly.

### 5. Round 2 results overlap round 1
- Without KEY0: the results flag stays set until KEY2, so the arbiter keeps the screen on the stats drawer. KEY1 loads new words into the scorer but never draws them.
- With KEY0: the clear FSM only clears the game screen. Drawers only write lit pixels, so new result digits are drawn on top of the old ones.

**Fix:** write background pixels in the drawers, and clear the results flag on KEY1.

### 6. Timing not met (Fmax 17.6 MHz vs 50 MHz)
Quartus inferred 25 combinational dividers: 12 in `stats_calculator`, 8 in `main.v` (digit splitting), 2 per drawer, 1 in the randomizer. The likely critical path is `correct × 100 / total` feeding `/10` and `%10` in one cycle. There is also no `.sdc` file, and non-constant values in the reset branches of `comparator` and `word_randomizer` create latches and make Quartus treat `KEY[0]` as a clock.
**Fix:** multi-cycle divider or double-dabble for the stats, constant reset values, and an `.sdc` with `create_clock` and `derive_pll_clocks`.

### 7. `comparator` is 60% of the logic
It reads `words_flat[bit_index +: 5]` with a runtime index inside an 8-iteration loop every cycle, which synthesizes to ~4,700 ALMs of muxes.
**Fix:** store the target list in block RAM and read one letter per keypress.

### Minor
- The accuracy box `y` in the clear table is `9'd1125`, which overflows 9 bits.
- The red numbers on the game screen are part of the background image. Live counts are on the HEX displays.
