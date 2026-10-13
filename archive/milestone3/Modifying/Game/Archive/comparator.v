module comparator (
    clock,
    resetn,
    start_new_test,      // pulse to clear indices + counters between tests
    typed_char,          // 0..26, LETTER_SPACE = 26
    typed_char_valid,    // 1-cycle pulse
    words_flat,          // flattened [word][letter] bus
    char_errors,
    word_errors
);

    input clock;
    input resetn;

    input start_new_test;
    input [4:0] typed_char;
    input typed_char_valid;

    // Match target_words / done_list parameters
    parameter n_letters = 8;
    parameter n_words   = 40;
    parameter [4:0] LETTER_SPACE = 5'd26;

    localparam N_TOTAL = n_letters * n_words;

    // Flattened words: entry 0 in bits [4:0], entry 1 in [9:5], etc.
    input [5*N_TOTAL-1:0] words_flat;

    // Error counters
    output reg [15:0] char_errors;
    output reg [15:0] word_errors;

    // Position in list
    reg [5:0] word_index;     // 0..(n_words-1)
    reg [2:0] letter_index;   // 0..(n_letters-1)

    // Current word stuffs
    reg [3:0] current_word_len;   // letters before space
    reg       current_word_wrong; // this word has any error

    // Helpers
    integer k;
    integer base_index;
    integer next_word_index;
    integer abs_index;   // absolute word/letter index = word*n_letters + letter
    integer bit_index;   // bit offset into words_flat = abs_index*5

    reg [3:0] tmp_len;
    reg seen_space;
    reg [4:0] expected_char;

    // Recompute current_word_len each word depending on word index
    task recompute_word_len;
    begin
        base_index = word_index * n_letters;
        tmp_len    = 4'd0;   // get length of word
        seen_space = 1'b0;

        for (k = 0; k < n_letters; k = k + 1) begin
            if (!seen_space) begin    // until we see a space 
                abs_index = base_index + k;
                bit_index = abs_index * 5;
                if (words_flat[bit_index +: 5] == LETTER_SPACE)
                    seen_space = 1'b1;
                else
                    tmp_len = tmp_len + 1'b1;
            end
        end

        current_word_len <= tmp_len;
    end
    endtask

    // Move to next word (or clamp at last) and reset length
    task goto_next_word;
    begin
        if (word_index < (n_words - 1))   // checking if we have hit max words 
            next_word_index = word_index + 1;
        else
            next_word_index = word_index;

        word_index         <= next_word_index;
        letter_index       <= 3'd0;
        current_word_wrong <= 1'b0;

        base_index = next_word_index * n_letters;
        tmp_len    = 4'd0;   // to count length of the current word 
        seen_space = 1'b0;   // have we seen or not 

        for (k = 0; k < n_letters; k = k + 1) begin
            if (!seen_space) begin    // keep going until we see a space 
                abs_index = base_index + k;
                bit_index = abs_index * 5;
                if (words_flat[bit_index +: 5] == LETTER_SPACE)
                    seen_space = 1'b1;
                else
                    tmp_len = tmp_len + 1'b1;
            end
        end

        current_word_len <= tmp_len;
    end
    endtask

    // Main 'game' logic
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin   // reset everything
            char_errors        <= 16'd0;
            word_errors        <= 16'd0;
            word_index         <= 6'd0;
            letter_index       <= 3'd0;
            current_word_wrong <= 1'b0;
            recompute_word_len();
        end else begin    // reset between each word test 
            if (start_new_test) begin
                char_errors        <= 16'd0;
                word_errors        <= 16'd0;
                word_index         <= 6'd0;
                letter_index       <= 3'd0;
                current_word_wrong <= 1'b0;
                recompute_word_len();
            end else if (typed_char_valid) begin  // if the char sent is valid
                base_index = word_index * n_letters;
                abs_index  = base_index + letter_index;
                bit_index  = abs_index * 5;
                expected_char = words_flat[bit_index +: 5];

                if (typed_char == LETTER_SPACE) begin   // if it is a space 
                    // End-of-word from user
                    if (expected_char == LETTER_SPACE) begin   // if we expected a space then it's fine
                        if (current_word_wrong)   // if the word was already wrong then increment word errors
                            word_errors <= word_errors + 16'd1;
                        goto_next_word();   // then we go to the next word
                    end else begin                               // word not finished
                        if (current_word_len > letter_index)  // typed fewer chars than expected
                            char_errors <= char_errors + (current_word_len - letter_index);     // char errors for however many were left
                        current_word_wrong <= 1'b1;
                        word_errors        <= word_errors + 16'd1;
                        goto_next_word();    // go to the next word and ignore the rest
                    end
                end else begin        // Non-space character
                    if (expected_char == LETTER_SPACE) begin           // Extra chars after word should have ended
                        char_errors        <= char_errors + 16'd1;
                        current_word_wrong <= 1'b1;
                        // stay on same letter_index, still expect a space
                    end else begin
                        // Inside word
                        if (typed_char != expected_char) begin
                            char_errors        <= char_errors + 16'd1;
                            current_word_wrong <= 1'b1;
                        end
                        if (letter_index < (n_letters - 1))
                            letter_index <= letter_index + 3'd1;   // go to the next letter 
                    end
                end
            end
        end
    end

endmodule