// Stores "completed" words in same layout as target_words and streams them out.

module done_list (clock, resetn, add_char, char_in, enable_send, char_sent, letter_ready, words);

    input clock, resetn;

    // Match target_words parameters
    parameter n_letters = 8;      // letters per word (including terminator/space slots)
    parameter n_words   = 40;     // maximum number of words
    parameter [4:0] LETTER_SPACE = 5'd26;   // code for space

    // words[word][letter] -> words[word*n_letters + letter]
    localparam N_TOTAL = n_words * n_letters;
    output reg [4:0] words [0:(N_TOTAL-1)]; // Total # of elements (N_TOTAL-1)

    integer i;

    // WRITE-SIDE INTERFACE (append)
    input  wire        add_char; 	    // 1-cycle: store char_in
    input  wire [4:0]  char_in;        // incoming letter or space

    reg [5:0] wr_word;           // index of word being filled
    reg [2:0] wr_letter;         // index of letter in that word
    reg [5:0] words_used;        // number of finalized words

    wire [9:0] wr_index;         // flattened write index
    assign wr_index = (wr_word * n_letters) + wr_letter;

    // READ-SIDE INTERFACE (stream)
    input  wire        enable_send;    // request next char
    output reg [4:0]   char_sent;      // char value out
    output reg         letter_ready;   // valid pulse

    reg [5:0] word_number;       // word index for reading
    reg [2:0] letter_number;     // letter index for reading
    reg       sending_space;     // next output is space between words
    reg       enable_send_d;     // delayed enable_send for ready pulse

    wire [9:0] rd_index;         // flattened read index
    wire [9:0] rd_next_index;    // next index in same word

    assign rd_index      = (word_number * n_letters) + letter_number;
    assign rd_next_index = rd_index + 1;

    // Highest word index that has been finalized
    wire [5:0] max_valid_word;
    assign max_valid_word = (words_used == 0) ? 6'd0 : (words_used - 1);
	
    // Fill all storage with spaces once at power-up.
    initial begin
        for (i = 0; i < N_TOTAL; i = i + 1) begin
            words[i] = LETTER_SPACE;
        end
    end

    // WRITE-SIDE SEQUENTIAL LOGIC

    // Appends letters and word separators from the input stream.
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            wr_word    <= 6'd0;
            wr_letter  <= 3'd0;
            words_used <= 6'd0;
        end else begin
            if (add_char) begin
                if (char_in == LETTER_SPACE) begin
                    // End of current word, move to next word.
                    if (wr_word < (n_words - 1)) begin
                        wr_word    <= wr_word + 6'd1;
                        wr_letter  <= 3'd0;
                        words_used <= wr_word + 6'd1;   // next free word index
                    end else begin
                        // List full: ignore additional words.
                        wr_word    <= wr_word;
                        wr_letter  <= wr_letter;
                        words_used <= words_used;
                    end
                end else begin
                    // Store a letter in the current word.
                    if (wr_index < N_TOTAL) begin
                        words[wr_index] <= char_in;
                    end

                    // Advance letter index up to last slot.
                    if (wr_letter < (n_letters - 1)) begin
                        wr_letter <= wr_letter + 3'd1;
                    end else begin
                        wr_letter <= wr_letter;  // ignore overflow letters
                    end
                    // words_used updated only when word is finalized by a space.
                end
            end
        end
    end

    // READ-SIDE SEQUENTIAL LOGIC

    // Streams stored words with spaces between them.
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            word_number   <= 6'd0;
            letter_number <= 3'd0;
            sending_space <= 1'b0;
            char_sent     <= LETTER_SPACE;
            letter_ready  <= 1'b0;
            enable_send_d <= 1'b0;
        end else begin
            // Delay enable_send for ready pulse.
            enable_send_d <= enable_send;
            letter_ready  <= 1'b0;

            // Advance only when requested.
            if (enable_send) begin
                if (sending_space) begin
                    // Output space between words
                    char_sent     <= LETTER_SPACE;
                    sending_space <= 1'b0;

                    // Move to next word, wrap at max_valid_word.
                    if (word_number == max_valid_word)
                        word_number <= 6'd0;
                    else
                        word_number <= word_number + 6'd1;
                end else begin
                    // Output letter from stored words.
                    char_sent <= words[rd_index];

                    // Increment letter position.
                    letter_number <= letter_number + 3'd1;

                    // End-of-word detection, space or last slot.
                    if ((letter_number == (n_letters - 1)) || (words[rd_next_index] == LETTER_SPACE)) begin
                        sending_space <= 1'b1;   // next output is space
                        letter_number <= 3'd0;   // reset for next word
                    end
                end
            end

            // One-cycle ready pulse after enable_send.
            if (enable_send_d)
                letter_ready <= 1'b1;
        end
    end

endmodule
