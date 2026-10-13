# Known issues

[← back to README](../README.md)

The game works in a demo, but going back through the code and the Quartus reports turned up the bugs below. The first four can be reproduced with the testbenches in `test/`.

### 1. Words 128–199 in the list never show up

In `target_words`, the address is calculated as `word_index = actual_word * 8 + letter_number`, and `word_index` is only 10 bits wide. With 200 words of 8 letters each, the last address is 1,599, which needs 11 bits. So any word number of 128 or above wraps around and lands on one of words 0–71. A round still shows 49 words, but around a third of them aren't the word the randomizer actually picked, and you can get repeats.

**Fix:** make `word_index` and `next_index` 11 bits. Test: `tb_target_words`.

### 2. Typing an 8-letter word correctly still counts as wrong

Every word gets 8 slots. Shorter words have a space after them that marks where they end, but an 8-letter word like `resistor` or `inductor` fills all 8 slots, so there's nothing left to mark the end. When you type it correctly and hit space, the comparator is still looking at the last letter. It decides you ended the word early and adds a character error and a word error.

**Fix:** give each word 9 slots, or treat reaching the 8th letter as the end of the word. Test: `tb_comparator`.

### 3. Rounds last 16 seconds, but WPM assumes 15

`countdown_timer` starts at 15 and counts down to 0, but it only signals that time's up one second *after* it reaches 0. The WPM formula assumes 15 seconds, so WPM comes out about 7% too high.

**Fix:** end the round when the timer goes from 1 to 0, or start it at 14. Test: `tb_timer`.

### 4. Wrong word length at the start of later rounds

When a new round starts, the comparator sets `word_index <= 0` and calls `recompute_word_len()` in the same clock cycle. Since it's a non-blocking assignment, `word_index` hasn't actually changed yet when the task runs, so it measures the word where the last round stopped instead of word 0. This only matters if you cut the first word short, because that's when the word length is used to count the missing letters. Pressing KEY0 between rounds hides it for now, but it'll show up once #5 is fixed.

**Fix:** calculate the length for word 0 directly when a round starts. Test: `tb_comparator`.

### 5. Playing a second round doesn't work properly

Our [game-flow diagram](diagrams/game_flow.png) has you press KEY0 between rounds. Either way, something goes wrong:

- **If you skip KEY0:** the results flag stays on until you press KEY2, so the screen is still being handed to the (idle) stats drawer. Pressing KEY1 loads new words into the scorer but never draws them. The next round shows the old words and scores you against the new ones.
- **If you press KEY0:** the clear logic only ever wipes the game screen and never touches the results screen. Our drawers only draw lit pixels and leave the background alone, so round 2's numbers get drawn right on top of round 1's.

**Fix:** have the drawers write the background pixels too, so each new number fully covers the old one. Also clear the results flag when KEY1 is pressed.

### 6. It doesn't meet timing

Quartus says the max frequency is 17.6 MHz, but the board runs at 50 MHz. The main reason is that Quartus built 25 divider circuits that each have to finish in one clock cycle:

- 12 in `stats_calculator`
- 8 in `main.v`, for splitting the error counts into digits
- 2 in each of the drawers
- 1 in the randomizer

The worst one is probably in `stats_calculator`, where `correct × 100 / total` goes straight into `/10` and `%10` in the same cycle.

There are two other problems. We never wrote an `.sdc` file, which is the file that tells Quartus what clock speeds you're targeting. And in `comparator` and `word_randomizer` we set some registers to non-constant values in the reset branch, which made Quartus build latches and treat `KEY[0]` as a clock.

**Fix:** spread the stats math over several clock cycles (a simple sequential divider, or double-dabble for the digits), only use constants in reset branches, and add an `.sdc` with `create_clock` and `derive_pll_clocks`.

### 7. The comparator is way bigger than it needs to be

The comparator reads the target letters with `words_flat[bit_index +: 5]`, where the index changes at runtime, and does it inside an 8-step loop that runs every clock cycle. That turns into about 4,700 ALMs of multiplexers.

**Fix:** keep the target list in block RAM and read one letter per keypress, since the comparator only ever needs the current letter.

### Smaller stuff

- In the box-clearing table, the accuracy box's `y` value is written as `9'd1125`, which doesn't fit in 9 bits.
- The red numbers on the game screen are part of the background image, not live values. The live counts are on the HEX displays.

## Running the tests

```
cd test && make
```

Bugs 1–4 show up as `XFAIL`. Once one is fixed, its test will print `XPASS` instead, and you can remove the known-bug flag from that testbench.
