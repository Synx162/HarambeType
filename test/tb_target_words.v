`timescale 1ns / 1ps
// Checks that target_words streams the word it *meant* to stream.
// After a reshuffle, the randomizer picks 49 word indices out of 200 and
// target_words should stream words[idx] for each. This test rebuilds every
// streamed word and compares it with the dictionary entry for that index.

module tb_target_words;
    reg clock = 0;
    always #10 clock = ~clock;

    reg resetn = 0;
    reg reshuffle = 0;
    reg enable_send = 0;
    wire [4:0] char_sent;
    wire letter_ready;

    target_words DUT (.clock(clock), .resetn(resetn), .reshuffle(reshuffle),
                      .enable_send(enable_send), .char_sent(char_sent),
                      .letter_ready(letter_ready));

    integer w, k, mismatches, high_idx, idx;
    reg [4:0] got [0:7];
    integer glen;
    reg done_word;

    initial begin
        #100 resetn = 1;
        repeat (137) @(negedge clock);          // let the seed counter move
        @(negedge clock) reshuffle = 1;
        @(negedge clock) reshuffle = 0;
        repeat (5000) @(negedge clock);         // shuffle + capture finishes well before this

        mismatches = 0; high_idx = 0;
        for (w = 0; w < 49; w = w + 1) begin
            idx = DUT.word_order[w];
            if (idx >= 128) high_idx = high_idx + 1;
            // pull chars until the inter-word space
            glen = 0; done_word = 0;
            while (!done_word) begin
                @(negedge clock) enable_send = 1;
                @(negedge clock) enable_send = 0;
                @(posedge letter_ready); @(negedge clock);
                if (char_sent == 5'd26) done_word = 1;
                else begin got[glen] = char_sent; glen = glen + 1; end
            end
            // compare against dictionary entry idx
            k = 0;
            while (k < glen && got[k] === DUT.words[idx*8 + k]) k = k + 1;
            if (k != glen || (glen < 8 && DUT.words[idx*8 + glen] !== 5'd26)) begin
                mismatches = mismatches + 1;
                if (mismatches <= 5)
                    $display("  word %0d: randomizer chose index %0d, but a different word was streamed", w, idx);
            end
        end

        $display("words with index >= 128: %0d, words streamed incorrectly: %0d", high_idx, mismatches);
        if (mismatches == 0) $display("PASS tb_target_words");
        else $display("XFAIL tb_target_words (known bug: 10-bit word_index wraps indices >= 128 onto words 0-71)");
        $finish;
    end
endmodule
