`timescale 1ns / 1ps
// Self-checking test for done_list + comparator: the scoring core.
// Loads a target word list into done_list (exactly how main.v does during
// preload), types a sequence into the comparator, and checks the char/word
// error counters against hand-computed expected values.
//
// Letter codes: a=0 .. z=25, space=26.

module tb_comparator;
    reg clock = 0;
    always #10 clock = ~clock;

    reg resetn = 0;
    reg add_char = 0;
    reg [4:0] char_in = 0;
    reg start_new_test = 0;
    reg [4:0] typed_char = 0;
    reg typed_valid = 0;

    localparam N_TOTAL = 8 * 40;
    wire [5*N_TOTAL-1:0] words_flat;
    wire [15:0] char_errors, word_errors, total_chars;

    done_list DL (.clock(clock), .resetn(resetn), .add_char(add_char), .char_in(char_in),
                  .enable_send(1'b0), .char_sent(), .letter_ready(), .words_flat(words_flat));

    comparator CMP (.clock(clock), .resetn(resetn), .start_new_test(start_new_test),
                    .typed_char(typed_char), .typed_char_valid(typed_valid),
                    .words_flat(words_flat), .char_errors(char_errors),
                    .word_errors(word_errors), .total_chars(total_chars));

    function [4:0] code(input [7:0] ascii);
        code = (ascii == " ") ? 5'd26 : ascii - "a";
    endfunction

    // Push a string into done_list one char per cycle
    task load(input [8*64-1:0] s, input integer len);
        integer i;
        begin
            for (i = len - 1; i >= 0; i = i - 1) begin
                @(negedge clock); add_char = 1; char_in = code(s[i*8 +: 8]);
            end
            @(negedge clock); add_char = 0;
        end
    endtask

    // Type a string into the comparator with a few idle cycles between keys
    task type_str(input [8*64-1:0] s, input integer len);
        integer i;
        begin
            for (i = len - 1; i >= 0; i = i - 1) begin
                @(negedge clock); typed_valid = 1; typed_char = code(s[i*8 +: 8]);
                @(negedge clock); typed_valid = 0;
                repeat (3) @(negedge clock);
            end
        end
    endtask

    task new_test;
        begin
            @(negedge clock); start_new_test = 1;
            @(negedge clock); start_new_test = 0;
        end
    endtask

    // known=1 marks a case that reproduces a documented bug (README "Known issues").
    // It is reported as XFAIL instead of failing the run; once the bug is fixed
    // it will show XPASS and the flag can be cleared.
    integer errors = 0, xfails = 0;
    task check(input [8*40-1:0] name, input integer ce, input integer we, input integer tc, input known);
        begin
            if (char_errors !== ce || word_errors !== we || total_chars !== tc) begin
                $display("%0s %0s: char_errors=%0d (exp %0d) word_errors=%0d (exp %0d) total=%0d (exp %0d)",
                         known ? "XFAIL" : "FAIL ", name, char_errors, ce, word_errors, we, total_chars, tc);
                if (known) xfails = xfails + 1; else errors = errors + 1;
            end else
                $display("%0s %0s: char_errors=%0d word_errors=%0d total=%0d", known ? "XPASS" : "ok   ", name, ce, we, tc);
        end
    endtask

    initial begin
        #100 resetn = 1;
        // Target list: "crash dish sink resistor gain "
        load("crash dish sink resistor gain ", 30);

        // 1) Perfect typing of the first three words
        new_test;
        type_str("crash dish sink ", 16);
        check("perfect", 0, 0, 16, 0);

        // 2) One wrong letter: 'crush' -> 1 char error, 1 word error
        new_test;
        type_str("crush ", 6);
        check("one typo", 1, 1, 6, 0);

        // 3) Word cut short: 'cra ' -> 2 missing chars, 1 word error.
        //    Known bug: on start_new_test the comparator recomputes the first
        //    word's length using the *old* word_index (non-blocking assignment),
        //    so it uses the length of the word the previous round stopped on
        //    ("dish", 4 letters) and charges 4-3 = 1 instead of 5-3 = 2.
        new_test;
        type_str("cra ", 4);
        check("short word after a previous round", 2, 1, 4, 1);

        // 4) Extra letters: 'crashh ' -> 1 char error, 1 word error
        new_test;
        type_str("crashh ", 7);
        check("extra letter", 1, 1, 7, 0);

        // 5) 8-letter word typed perfectly.
        //    EXPECTED behaviour: 0 errors. This case documents a known bug:
        //    an 8-letter word fills every slot, so there is no terminating
        //    space for the comparator to find and the correct space is scored
        //    as "word ended early".
        new_test;
        type_str("crash dish sink resistor ", 25);
        check("8-letter word typed correctly", 0, 0, 25, 1);

        if (errors == 0) $display("PASS tb_comparator (%0d known bug(s) reproduced)", xfails);
        else             $display("FAIL tb_comparator: %0d case(s) failed", errors);
        $finish;
    end
endmodule
