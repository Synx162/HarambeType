# Icarus Verilog regression for HarambeType.
#   make        -> run every test
#   make input  -> run one test
#
# Requires: iverilog (apt install iverilog / brew install icarus-verilog)

SRC   := ../src
BUILD := build
IV    := iverilog -g2005 -Wall -Wno-timescale -Wno-implicit-dimensions -Wno-portbind

TESTS := input comparator target_words timer

.PHONY: all $(TESTS) clean
all: $(TESTS)

$(BUILD):
	@mkdir -p $(BUILD)

input: | $(BUILD)
	@$(IV) -o $(BUILD)/$@.vvp tb_input.v $(SRC)/Input/ps2_receiver.v $(SRC)/Input/scancode_to_fontIndex.v
	@vvp -n $(BUILD)/$@.vvp | grep -E "PASS|FAIL|ok  |XFAIL|XPASS"

comparator: | $(BUILD)
	@$(IV) -o $(BUILD)/$@.vvp tb_comparator.v $(SRC)/Game/done_list.v $(SRC)/Game/comparator.v
	@vvp -n $(BUILD)/$@.vvp | grep -E "PASS|FAIL|ok  |XFAIL|XPASS"

target_words: | $(BUILD)
	@$(IV) -o $(BUILD)/$@.vvp tb_target_words.v $(SRC)/Memory/target_words.v $(SRC)/Game/word_randomizer.v
	@vvp -n $(BUILD)/$@.vvp | grep -vE "^VCD|finish"

# timer.v counts to 49_999_999 (1 s at 50 MHz); shrink it so simulation is instant
timer: | $(BUILD)
	@sed 's/26.d49_999_999/26'"'"'d99/' $(SRC)/Game/timer.v > $(BUILD)/timer_fast.v
	@$(IV) -o $(BUILD)/$@.vvp tb_timer.v $(BUILD)/timer_fast.v
	@vvp -n $(BUILD)/$@.vvp | grep -vE "finish"

clean:
	rm -rf $(BUILD)
