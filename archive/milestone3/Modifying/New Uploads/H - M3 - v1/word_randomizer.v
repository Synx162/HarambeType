// Standalone LFSR-based word index randomizer
// Generates unique random word indices (0-199) without repetition
// Uses free-running counter for unique seed on each reshuffle

module word_randomizer (
    clock,
    resetn,
    reshuffle,       // pulse to generate new random sequence
    get_next,        // pulse to get next word index
    word_index,      // output random word index (0-199)
    index_ready,     // pulse when new index is available
    shuffle_done     // high when all indices generated
);

    input wire clock;
    input wire resetn;
    input wire reshuffle;
    input wire get_next;
    
    output reg [7:0] word_index;
    output reg index_ready;
    output reg shuffle_done;
    
    parameter MAX_WORDS = 8'd200;
    
    // FSM States
    parameter [1:0] IDLE      = 2'd0,
                    SHUFFLING = 2'd1,
                    DONE      = 2'd2;
    
    reg [1:0] state;
    
    // 8-bit LFSR (taps at 8,6,5,4 for maximal-length sequence)
    reg [7:0] lfsr;
    
    // Free-running counter for unique seed
    reg [15:0] seed_counter;
    
    // Track which words have been used
    reg [199:0] used_words;
    reg [7:0] words_used_count;
    reg [7:0] shuffle_count;
    
    // Temporary for checking index
    reg [7:0] candidate_index;
    
    // Free-running counter (always incrementing for time-based seed)
    always @(posedge clock or negedge resetn) begin
        if (!resetn)
            seed_counter <= 16'd1;
        else
            seed_counter <= seed_counter + 16'd1;
    end
    
    // FSM Logic
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            lfsr <= seed_counter[7:0] | 8'b00000001;
            word_index <= 8'd0;
            index_ready <= 1'b0;
            shuffle_done <= 1'b0;
            used_words <= 200'd0;
            words_used_count <= 8'd0;
            shuffle_count <= 8'd0;
            candidate_index <= 8'd0;
        end else begin
            // Default outputs
            index_ready <= 1'b0;
            
            if (state == IDLE) begin
                shuffle_done <= 1'b0;
                
                if (reshuffle) begin
                    // Start new shuffle
                    state <= SHUFFLING;
                    shuffle_count <= 8'd0;
                    used_words <= 200'd0;
                    words_used_count <= 8'd0;
                    // Seed with current time for uniqueness
                    lfsr <= seed_counter[7:0] | 8'b00000001;
                end else if (get_next && words_used_count < MAX_WORDS) begin
                    // Manual request for next index
                    lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
                    candidate_index <= lfsr % MAX_WORDS;
                    
                    if (!used_words[candidate_index]) begin
                        word_index <= candidate_index;
                        used_words[candidate_index] <= 1'b1;
                        words_used_count <= words_used_count + 8'd1;
                        index_ready <= 1'b1;
                    end
                end
                
                // Auto-reset when all words exhausted
                if (words_used_count >= MAX_WORDS) begin
                    used_words <= 200'd0;
                    words_used_count <= 8'd0;
                    lfsr <= seed_counter[7:0] | 8'b00000001;
                end
            end else if (state == SHUFFLING) begin
                if (shuffle_count < MAX_WORDS) begin
                    // Advance LFSR
                    lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
                    candidate_index <= lfsr % MAX_WORDS;
                    
                    // Check if this index hasn't been used
                    if (!used_words[candidate_index]) begin
                        word_index <= candidate_index;
                        used_words[candidate_index] <= 1'b1;
                        words_used_count <= words_used_count + 8'd1;
                        shuffle_count <= shuffle_count + 8'd1;
                        index_ready <= 1'b1;
                    end
                end else begin
                    // Shuffling complete
                    state <= DONE;
                end
            end else if (state == DONE) begin
                shuffle_done <= 1'b1;
                state <= IDLE;
            end else begin
                state <= IDLE;
            end
        end
    end
endmodule