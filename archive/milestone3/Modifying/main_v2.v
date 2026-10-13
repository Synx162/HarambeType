module main (CLOCK_50, KEY, PS2_CLK, PS2_DAT, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK,
			 HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);

    input  wire CLOCK_50;
    input  wire [3:0]KEY;
    inout  wire PS2_CLK;
    inout  wire PS2_DAT;
    output wire [7:0]VGA_R;
    output wire [7:0]VGA_G;
    output wire [7:0]VGA_B;
    output wire VGA_HS;
    output wire VGA_VS;
    output wire VGA_BLANK_N;
    output wire VGA_SYNC_N;
    output wire VGA_CLK;
    output wire [6:0] HEX0;  // Timer ones
    output wire [6:0] HEX1;  // Timer tens
    output wire [6:0] HEX2;  // Char errors ones
    output wire [6:0] HEX3;  // Char errors tens
    output wire [6:0] HEX4;  // Word errors ones
    output wire [6:0] HEX5;  // Word errors tens

    // Reset
    wire resetn = KEY[0];

    // PS/2 receiver
    wire [7:0] scancode;
    wire       sc_rdy;

    ps2_receiver PS2_RX (
        .CLOCK_50 (CLOCK_50),
        .Resetn   (resetn),
        .PS2_CLK  (PS2_CLK),
        .PS2_DAT  (PS2_DAT),
        .scancode (scancode),
        .ps2_rec  (sc_rdy)
    );

    // Decode scancode -> 5-bit index (0..25 letters, 26 space) + ready
    wire [7:0] inputChar;
    wire       inputChar_rdy;

    scancode_to_fontIndex DECODER (
        .clock         (CLOCK_50),
        .resetn        (resetn),
        .sc            (scancode),
        .sc_rdy        (sc_rdy),
        .inputChar     (inputChar),
        .inputChar_rdy (inputChar_rdy)
    );

    // keyboard char path (raw from decoder)
    wire [4:0] kb_char_index = inputChar[4:0];
    wire       kb_char_valid = inputChar_rdy;

    // Gate keyboard input with drawer_busy & latch accepted char
    reg  [4:0] kb_char_reg;
    reg        kb_char_valid_d;
    reg        kb_char_valid_pulse;   // central "typed char" pulse

    // separate busy/done for kb + preload, then combine into drawer_busy/done
    wire drawer_busy_kb;
    wire drawer_done_kb;
    wire drawer_busy_pre;
    wire drawer_done_pre;
    wire drawer_busy;
    wire drawer_done;

    wire kb_char_valid_edge = kb_char_valid & ~kb_char_valid_d; // rising edge detect

    // (typing only while timer running)
    reg  timer_start_d;
    wire timer_start_level;
    wire timer_start_pulse;
    reg  typing_active;             // 1 = game running, keyboard has effect
    reg  game_over_latched;         // latched when timer hits 0
    reg  timer_running;             // 1 = TIMER IS CURRENTLY COUNTING
    reg  nextScreen;                // 0 = background1, 1 = background2 (post-game)

    assign timer_start_level = ~KEY[2]; // KEY[2] active-low start button

	// latching to enable typing 
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            timer_start_d     <= 1'b0;
            typing_active     <= 1'b0;
            game_over_latched <= 1'b0;
        end else begin
            timer_start_d <= timer_start_level;

            // RESET GAME STATE ON NEW TEST (KEY2 ONLY NOW)
            if (global_test_reset_pulse) begin
                typing_active     <= 1'b0;
                game_over_latched <= 1'b0;
            end

            // START GAME WHEN KEY2 PULSE GOES TO TIMER
            if (timer_start_pulse) begin
                typing_active     <= 1'b1;
                game_over_latched <= 1'b0;
            end

            if (timer_expired) begin
                typing_active     <= 1'b0;
                game_over_latched <= 1'b1;
            end
        end
    end

    assign timer_start_pulse = timer_start_level & ~timer_start_d; // 1-cycle pulse on KEY2 press

    wire game_active     = typing_active;      // for in-game stats
    wire post_game_phase = game_over_latched;  // for post-game stats screen

    // TIMER RUNNING FLAG FOR DISPLAY CONTROL
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            timer_running <= 1'b0;
        end else begin
            if (timer_start_pulse) begin
                timer_running <= 1'b1;
            end else if (timer_expired) begin
                timer_running <= 1'b0;
            end
        end
    end

    // BACKGROUND SWITCH LATCH (screen1 -> screen2 on timer_expired)
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            nextScreen <= 1'b0;                    // start on background1
        end else begin
            if (global_test_reset_pulse) begin
                nextScreen <= 1'b0;                // new test returns to background1
            end else if (timer_expired) begin
                nextScreen <= 1'b1;                // switch to background2 when time is up
            end
        end
    end

    // KB ACCEPTANCE (respect typing_active) 
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            kb_char_valid_d      <= 1'b0;
            kb_char_valid_pulse  <= 1'b0;
            kb_char_reg          <= 5'd0;
        end else begin
            kb_char_valid_d      <= kb_char_valid;
            kb_char_valid_pulse  <= 1'b0;  // default

            // minimal but safe gating: only block when drawer busy, preloading, clearing, or game inactive
            if (kb_char_valid_edge && !drawer_busy && !preload_mode && !clearing && typing_active) begin
                kb_char_reg         <= kb_char_index;
                kb_char_valid_pulse <= 1'b1; // single central "typed char" pulse
            end
        end
    end

    // target_words interface
    wire [4:0] tw_char_sent;
    wire       tw_letter_ready;
    reg        tw_enable;

    // preload controller
    reg        preload_mode;       // 1 = using target_words stream
    reg        preload_mode_prev;  // track edge of preload_mode
    reg [7:0]  preload_count;
    reg [9:0]  preload_col;        // logical preload cursor (advances through grid)
    reg [9:0]  preload_row;
    reg [9:0]  preload_draw_col;   // column used for current character draw
    reg [9:0]  preload_draw_row;   // row used for current character draw

    // latch for target_words outputs
    reg [4:0]  tw_char_reg;
    reg        tw_valid_reg;

    // preload FSM state
    parameter [1:0] PR_IDLE        = 2'd0,
                    PR_WAIT_LETTER = 2'd1,
                    PR_WAIT_DONE   = 2'd2;
    reg [1:0] preload_state;

    parameter MIN_PRELOAD_CHARS = 175;

    // Cursor control for keyboard typing
    parameter TEXT_COLS = 34;
    parameter TEXT_ROWS = 7;

    reg [9:0] cursor_col;
    reg [9:0] cursor_row;

    reg  wrapped_back; // detect wrap for clear

    // combine busy/done from the active drawer (preload or keyboard)
    assign drawer_busy = preload_mode ? drawer_busy_pre : drawer_busy_kb;
    assign drawer_done = preload_mode ? drawer_done_pre : drawer_done_kb;

    // KEY1 edge detection for preload trigger (active-low button)
    reg  key1_prev;
    wire key1_pressed = (key1_prev == 1'b1) && (KEY[1] == 1'b0); // 1->0 edge

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            key1_prev <= 1'b1; // assume unpressed at reset
        end else begin
            key1_prev <= KEY[1];
        end
    end

    // Cursor control for keyboard typing (not for preload)
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            cursor_col   <= 10'd0;
            cursor_row   <= 10'd0;
            wrapped_back <= 1'b0;
        end else begin
            wrapped_back <= 1'b0;

            // advance only on character draws in keyboard mode
            if (drawer_done && !preload_mode) begin
                if (cursor_col == (TEXT_COLS - 1)) begin
                    cursor_col <= 10'd0;
                    if (cursor_row == (TEXT_ROWS - 1)) begin
                        cursor_row   <= 10'd0;
                        wrapped_back <= 1'b1;
                    end else begin
                        cursor_row <= cursor_row + 10'd1;
                    end
                end else begin
                    cursor_col <= cursor_col + 10'd1;
                end
            end
        end
    end

    // preload controller FSM
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            preload_mode      <= 1'b0;
            preload_state     <= PR_IDLE;
            preload_count     <= 8'd0;
            preload_col       <= 10'd0;
            preload_row       <= 10'd0;
            preload_draw_col  <= 10'd0;
            preload_draw_row  <= 10'd0;
            tw_char_reg       <= 5'd0;
            tw_valid_reg      <= 1'b0;
            tw_enable         <= 1'b0;
        end else begin
            tw_enable    <= 1'b0;
            tw_valid_reg <= 1'b0;

            if (!preload_mode) begin
                // start preload on KEY1 press when not clearing AND NOT RUNNING GAME
                if (key1_pressed && !clearing && !typing_active) begin
                    preload_mode     <= 1'b1;
                    preload_state    <= PR_IDLE;
                    preload_count    <= 8'd0;
                    preload_col      <= 10'd0;
                    preload_row      <= 10'd0;
                    preload_draw_col <= 10'd0;
                    preload_draw_row <= 10'd0;
                end
            end else begin
                // stop preload once we have enough chars and just saw a space
                if ((preload_count >= MIN_PRELOAD_CHARS) && (tw_char_reg == 5'd26)) begin
                    preload_mode  <= 1'b0;
                    preload_state <= PR_IDLE;
                end else if (!clearing) begin
                    case (preload_state)
                        PR_IDLE: begin
                            if (!drawer_busy) begin
                                tw_enable     <= 1'b1;       // ask target_words for next char
                                preload_state <= PR_WAIT_LETTER;
                            end
                        end

                        PR_WAIT_LETTER: begin
                            if (tw_letter_ready) begin
                                tw_char_reg       <= tw_char_sent;
                                tw_valid_reg      <= 1'b1;             // 1-cycle char_valid pulse
                                preload_draw_col  <= preload_col;      // used by drawer
                                preload_draw_row  <= preload_row;

                                // advance logical preload cursor
                                preload_count <= preload_count + 1'b1;
                                if (preload_col == (TEXT_COLS - 1)) begin
                                    preload_col <= 10'd0;
                                    preload_row <= preload_row + 10'd1;
                                end else begin
                                    preload_col <= preload_col + 10'd1;
                                end

                                preload_state <= PR_WAIT_DONE;
                            end
                        end

                        PR_WAIT_DONE: begin
                            if (drawer_done) begin
                                preload_state <= PR_IDLE;
                            end
                        end

                        default: begin
                            preload_state <= PR_IDLE;
                        end
                    endcase
                end
            end
        end
    end

    // track previous preload_mode (used for preload start pulse)
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            preload_mode_prev <= 1'b0;
        end else begin
            preload_mode_prev <= preload_mode;
        end
    end

    // PRELOAD START PULSE: 0->1 EDGE OF preload_mode (used only for done_list reset)
    wire preload_start_pulse = ~preload_mode_prev & preload_mode; // decoupled from game start

    // GLOBAL TEST RESET PULSE: ONLY WHEN GAME STARTS (KEY2)
    wire global_test_reset_pulse = timer_start_pulse;

    // 3-bit background color
    parameter [2:0] BACKGROUND_COLOR = 3'b000; // explicit 3-bit

    // Font ROM (letters) – 3-bit
    wire [10:0] font_addr_kb;
    wire [10:0] font_addr_pre;
    wire [10:0] font_addr;
    wire [2:0]  font_q9;          // 3-bit font data

    font_mem #(.n(3), .Mn(11), .INIT_FILE("font_216_3.mif"))
    FONT_ROM (.address (font_addr), .clock(CLOCK_50), .q(font_q9));

    assign font_addr = preload_mode ? font_addr_pre : font_addr_kb;

    // Digit ROM for post-game stats – 3-bit
    wire [9:0] num_addr_stats;
    wire [2:0] num_q9_stats;

    num_mem #(.n(3), .Mn(10), .INIT_FILE("numbers_80_3.mif"))
    NUM_ROM_STATS (
        .address (num_addr_stats),
        .clock   (CLOCK_50),
        .q       (num_q9_stats)
    );

    // countdown timer for typing test (15 -> 0 seconds)
    wire [3:0] timer_value;
    wire       timer_expired;
    wire       timer_update_raw;   // 1 Hz pulse from timer

    countdown_timer TIMER (
        .clock        (CLOCK_50),
        .resetn       (resetn),
        .start        (timer_start_pulse), // STARTS ONLY ON KEY2 PULSE
        .timer_value  (timer_value),
        .timer_expired(timer_expired),
        .update_pulse (timer_update_raw)
    );

    // split timer_value (0..15) into tens/ones digits for drawing
    reg [3:0] digit_tens;
    reg [3:0] digit_ones;

    always @(*) begin
        if (timer_running) begin                    // WHEN TIMER RUNNING USE LIVE VALUE
            if (timer_value >= 4'd10) begin
                digit_tens = 4'd1;
                digit_ones = timer_value - 4'd10;
            end else begin
                digit_tens = 4'd0;
                digit_ones = timer_value;
            end
        end else begin                              // WHEN NOT RUNNING SHOW FULL TIME (15)
            digit_tens = 4'd1;
            digit_ones = 4'd5;
        end
    end


    // fixed cursor for counter box (uses internal H_MARGIN/V_MARGIN in num_to_pixel_draw)
    wire [9:0] counter_cursor_col = 10'd0;
    wire [9:0] counter_cursor_row = 10'd0;

	// Declare wire
	wire shuffle_done;

	// Connect in instantiation
	target_words TARGET_WORDS (
		.clock(CLOCK_50),
		.resetn(resetn),
		.reshuffle(key1_pressed),
		.enable_send(tw_enable),
		.char_sent(tw_char_sent),
		.letter_ready(tw_letter_ready),
		.shuffle_done(shuffle_done)    // ADD THIS
	);
	

    // Parameters shared with done_list/comparator word storage
    localparam N_LETTERS = 8;
    localparam N_WORDS   = 40;
    localparam N_TOTAL   = N_LETTERS * N_WORDS;

    // Flattened word list from done_list for comparator (5 bits per char * N_TOTAL chars)
    wire [5*N_TOTAL-1:0] done_words_flat;
    wire [15:0]          char_errors;
    wire [15:0]          word_errors;
    wire [15:0]          total_chars;   

    // digits for error stats + post-game stats
    reg [3:0] cerr_hundreds, cerr_tens, cerr_ones;
    reg [3:0] werr_hundreds, werr_tens, werr_ones;
    reg [3:0] acc_hundreds, acc_tens, acc_ones;
    reg [3:0] wpm_hundreds, wpm_tens, wpm_ones;
    reg [9:0] cerr_val_clip, werr_val_clip;

    wire [11:0] wpm_bcd;
    wire [11:0] accuracy_bcd;
	
	reg pg_draw_done;   // tells us when the post game stats are done drawing to prevent further draws

    always @(*) begin
        // max errors is 999
        if (char_errors > 16'd999)
            cerr_val_clip = 10'd999;
        else
            cerr_val_clip = char_errors[9:0];

        if (word_errors > 16'd999)
            werr_val_clip = 10'd999;
        else
            werr_val_clip = word_errors[9:0];

        cerr_hundreds = cerr_val_clip / 100;
        cerr_tens     = (cerr_val_clip / 10) % 10;
        cerr_ones     = cerr_val_clip % 10;

        werr_hundreds = werr_val_clip / 100;
        werr_tens     = (werr_val_clip / 10) % 10;
        werr_ones     = werr_val_clip % 10;

        // decode BCD outputs from stats_calculator
        acc_hundreds = accuracy_bcd[11:8];
        acc_tens     = accuracy_bcd[7:4];
        acc_ones     = accuracy_bcd[3:0];

        wpm_hundreds = wpm_bcd[11:8];
        wpm_tens     = wpm_bcd[7:4];
        wpm_ones     = wpm_bcd[3:0];
    end

    // for per-char correctness tracking
    wire typed_char_valid;   // centralized typed_valid to comparator & stats
    reg  typed_char_valid_d1; // 1-cycle delay
    reg [15:0] prev_char_errors;   // to detect increments
    reg current_char_correct; // 1 = comparator did not add char error for that char

    // typed_char_valid is now exactly "accepted key" pulse
    assign typed_char_valid = kb_char_valid_pulse; 

    // LOCAL RESET FOR DONE_LIST: RESETN AND PRELOAD START
    wire resetn_done_list = resetn & ~preload_start_pulse; // PULSE LOW AT START OF EACH PRELOAD

    // Capture target words into done_list during preload
    done_list DONE_LIST (
        .clock       (CLOCK_50),
        .resetn      (resetn_done_list),
        .add_char    (tw_valid_reg & preload_mode & ~clearing),
        .char_in     (tw_char_reg),
        .enable_send (1'b0),
        .char_sent   (),
        .letter_ready(),
        .words_flat  (done_words_flat)
    );

    // Compare typed characters against stored target words
    comparator COMPARATOR (
        .clock            (CLOCK_50),
        .resetn           (resetn),
        .start_new_test   (global_test_reset_pulse),
        .typed_char       (kb_char_reg),
        .typed_char_valid (typed_char_valid),
        .words_flat       (done_words_flat),
        .char_errors      (char_errors),
        .word_errors      (word_errors),
        .total_chars      (total_chars)
    );

    // Stats calculator: WPM + accuracy BCD
    stats_calculator STATS_CALC (
        .clock         (CLOCK_50),
        .resetn        (resetn),
        .start_new_test(global_test_reset_pulse),
        .timer_expired (timer_expired),
        .char_errors   (char_errors),
        .total_chars   (total_chars),
        .wpm_bcd       (wpm_bcd),
        .accuracy_bcd  (accuracy_bcd)
    );

    // Per-character correctness based on char_errors change (for color)
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            typed_char_valid_d1  <= 1'b0;
            prev_char_errors     <= 16'd0;
            current_char_correct <= 1'b1;
        end else begin
            typed_char_valid_d1 <= typed_char_valid;

            if (global_test_reset_pulse) begin
                prev_char_errors     <= 16'd0;
                current_char_correct <= 1'b1;
            end else if (typed_char_valid_d1) begin
                // if char_errors didn't increase, char was correct
                current_char_correct <= (char_errors == prev_char_errors);
                prev_char_errors     <= char_errors;
            end
        end
    end

    // Keyboard drawer outputs
    wire [9:0] draw_x_kb;
    wire [8:0] draw_y_kb;
    wire [2:0] draw_color_kb;          // 3-bit
    wire       draw_write_kb;

    // Preload drawer outputs
    wire [9:0] draw_x_pre;
    wire [8:0] draw_y_pre;
    wire [2:0] draw_color_pre;         // 3-bit
    wire       draw_write_pre;

    // Post-game stats drawer outputs 
    wire [9:0] draw_x_stats_pg;
    wire [8:0] draw_y_stats_pg;
    wire [2:0] draw_color_stats_pg;    // 3-bit
    wire       draw_write_stats_pg;
    wire       stats_busy_pg;
    wire       stats_done_pg;

    // Color constants for correctness (3-bit)
    localparam [2:0] COLOR_CORRECT   = 3'b111; // "white"
    localparam [2:0] COLOR_INCORRECT = 3'b100; // "red-ish"

    wire [2:0] draw_color_kb_colored;

    assign draw_color_kb_colored = draw_write_kb ? (current_char_correct ? COLOR_CORRECT : COLOR_INCORRECT) : draw_color_kb; 

    // Keyboard drawer: uses bottom text box
    char_to_pixel_draw CHAR_DRAW ( 
        .char_index   (kb_char_reg),
        .char_valid   (typed_char_valid),
        .clock        (CLOCK_50),
        .resetn       (resetn),
        .cursor_col   (cursor_col),
        .cursor_row   (cursor_row),
        .busy         (drawer_busy_kb),
        .done         (drawer_done_kb),
        .font_address (font_addr_kb),
        .font_color9  (font_q9),          // 3-bit font data
        .x            (draw_x_kb),
        .y            (draw_y_kb),
        .color        (draw_color_kb),    // 3-bit
        .write        (draw_write_kb)
    );

    // Preload drawer: draws target words using top text box margins
    preload_to_pixel_draw PRELOAD_DRAW ( 
        .char_index   (tw_char_reg),
        .char_valid   (tw_valid_reg & ~clearing & preload_mode),
        .clock        (CLOCK_50),
        .resetn       (resetn),
        .cursor_col   (preload_draw_col),
        .cursor_row   (preload_draw_row),
        .busy         (drawer_busy_pre),
        .done         (drawer_done_pre),
        .font_address (font_addr_pre),
        .font_color9  (font_q9),          // 3-bit
        .x            (draw_x_pre),
        .y            (draw_y_pre),
        .color        (draw_color_pre),   // 3-bit
        .write        (draw_write_pre)
    );

    // Text draw mux (kb vs preload)
    wire [9:0] draw_x_text;
    wire [8:0] draw_y_text;
    wire [2:0] draw_color_text;      // 3-bit
    wire       draw_write_text;

    assign draw_x_text     = preload_mode ? draw_x_pre          : draw_x_kb;
    assign draw_y_text     = preload_mode ? draw_y_pre          : draw_y_kb;
    assign draw_color_text = preload_mode ? draw_color_pre      : draw_color_kb_colored;
    assign draw_write_text = preload_mode ? draw_write_pre      : draw_write_kb;

    // === IN-GAME STATS DRAWER – 3-bit === 
    wire stats_valid_ig = game_active;       


    // === POST-GAME STATS DRAWER – 3-bit === 
    wire stats_valid_pg = post_game_phase & ~pg_draw_done;   // ensures 1 draw

    stats_to_pixel_draw POSTGAME_STATS (
        .acc_tens      (acc_tens),
        .acc_ones      (acc_ones),
        .werr_tens     (werr_tens),
        .werr_ones     (werr_ones),
        .cerr_tens     (cerr_tens),
        .cerr_ones     (cerr_ones),
        .wpm_tens      (wpm_tens),
        .wpm_ones      (wpm_ones),
        .stats_valid   (stats_valid_pg),
        .clock         (CLOCK_50),
        .resetn        (resetn),
        .acc_col       (10'd0),
        .acc_row       (10'd0),
        .werr_col      (10'd0),
        .werr_row      (10'd1),
        .cerr_col      (10'd0),
        .cerr_row      (10'd2),
        .wpm_col       (10'd0),
        .wpm_row       (10'd3),
        .num_address   (num_addr_stats),
        .num_color9    (num_q9_stats),       // 3-bit
        .x             (draw_x_stats_pg),
        .y             (draw_y_stats_pg),
        .color         (draw_color_stats_pg),// 3-bit
        .write         (draw_write_stats_pg),
        .busy          (stats_busy_pg),
        .done          (stats_done_pg),
        .acc_hundreds  (acc_hundreds),
        .werr_hundreds (werr_hundreds),
        .cerr_hundreds (cerr_hundreds),
        .wpm_hundreds  (wpm_hundreds)
    );
	
	
	// latching to ensure post game stats are only drawn once
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            pg_draw_done <= 1'b0;
        end else begin
            if (global_test_reset_pulse) begin
                // new test: allow post-game stats to be drawn again
                pg_draw_done <= 1'b0;
            end else if (stats_done_pg) begin
                // once post-game stats drawer finishes, freeze it
                pg_draw_done <= 1'b1;
            end
        end
    end

	// Arbiter
	
    localparam ARB_TEXT = 1'b0;
    localparam ARB_PG   = 1'b1;
    
    reg arb_src;
    
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            arb_src <= ARB_TEXT;
        end else if (global_test_reset_pulse) begin
            arb_src <= ARB_TEXT;
        end else if (clearing) begin
            arb_src <= ARB_TEXT;
        end else if (post_game_phase) begin
            arb_src <= ARB_PG;
        end else begin
            arb_src <= ARB_TEXT;
        end
    end
    
    // Final mux
    wire [9:0] draw_x;
    wire [8:0] draw_y;
    wire [2:0] draw_color;
    wire       draw_write;
    
    assign draw_x     = (arb_src == ARB_PG) ? draw_x_stats_pg     : draw_x_text;
    assign draw_y     = (arb_src == ARB_PG) ? draw_y_stats_pg     : draw_y_text;
    assign draw_color = (arb_src == ARB_PG) ? draw_color_stats_pg : draw_color_text;
    assign draw_write = (arb_src == ARB_PG) ? draw_write_stats_pg : draw_write_text;


    // CLEARING + VGA OUTPUT

    reg        clearing;
    reg [2:0]  box_id;
    reg [2:0]  max_box_id;
    reg [9:0]  clear_x;
    reg [8:0]  clear_y;
    reg [9:0]  box_x0;
    reg [8:0]  box_y0;
    reg [9:0]  box_w;
    reg [8:0]  box_h;
    // choose which text box to clear
    always @(*) begin
        case (box_id)
            3'd0: begin
                // bottom typing box
                box_x0 = 10'd50;
                box_y0 = 9'd280;
                box_w  = 10'd544;
                box_h  = 9'd80;
            end
            3'd1: begin
                // top preload/target box
                box_x0 = 10'd50;
                box_y0 = 9'd120;
                box_w  = 10'd544;
                box_h  = 9'd120;
            end
            3'd2: begin
                // accuracy box
                box_x0 = 10'd435;
                box_y0 = 9'd1125;
                box_w  = 10'd80;   // >48
                box_h  = 9'd60;
            end
            3'd3: begin                                           
                // word errors box 
                box_x0 = 10'd435;
                box_y0 = 9'd210;
                box_w  = 10'd80;
                box_h  = 9'd52;
            end
            3'd4: begin                                           
                // char errors box 
                box_x0 = 10'd435;
                box_y0 = 9'd300;
                box_w  = 10'd80;
                box_h  = 9'd60;
            end
            3'd5: begin                                           
                // WPM
                box_x0 = 10'd435;
                box_y0 = 9'd390;
                box_w  = 10'd80;
                box_h  = 9'd60;
			end
			
            default: begin
                box_x0 = 10'd0;
                box_y0 = 9'd0;
                box_w  = 10'd1;
                box_h  = 9'd1;
            end
        endcase
    end
    // clear FSM
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            clearing   <= 1'b1;      // on reset clear all boxes
            box_id     <= 3'd0;
            max_box_id <= 3'd5;      // boxes 0, 1, 2, 3, 4, 5
            clear_x    <= 10'd0;
            clear_y    <= 9'd0;
        end else begin
            // on wrap, clear only typing box (0)
            if (wrapped_back && !clearing) begin
                clearing   <= 1'b1;
                box_id     <= 3'd0;
                max_box_id <= 3'd0;
                clear_x    <= 10'd0;
                clear_y    <= 9'd0;
            end else if (clearing) begin
                if (clear_x == (box_w - 1)) begin
                    clear_x <= 10'd0;
                    if (clear_y == (box_h - 1)) begin
                        clear_y <= 9'd0;
                        if (box_id == max_box_id) begin
                            clearing <= 1'b0;
                        end else begin
                            box_id <= box_id + 3'd1;
                        end
                    end else begin
                        clear_y <= clear_y + 9'd1;
                    end
                end else begin
                    clear_x <= clear_x + 10'd1;
                end
            end
        end
    end
    // VGA mux between clear pixels and normal draw pixels
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [2:0] vga_color;       // 3-bit
    wire       vga_write;
    assign vga_x     = clearing ? (box_x0 + clear_x) : draw_x;
    assign vga_y     = clearing ? (box_y0 + clear_y) : draw_y;
    assign vga_color = clearing ? BACKGROUND_COLOR : draw_color;
    assign vga_write = clearing ? 1'b1 : draw_write;

    // VGA adapter
    vga_adapter VGA (
        .resetn      (resetn),
        .clock       (CLOCK_50),
        .nextScreen  (nextScreen),
        .x           (vga_x),
        .y           (vga_y),
        .color       (vga_color),    // 3-bit color into adapter
        .write       (vga_write),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

    // 7-segment decoder (BCD)
    function [6:0] hex_to_7seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_7seg = 7'b1000000;
                4'h1: hex_to_7seg = 7'b1111001;
                4'h2: hex_to_7seg = 7'b0100100;
                4'h3: hex_to_7seg = 7'b0110000;
                4'h4: hex_to_7seg = 7'b0011001;
                4'h5: hex_to_7seg = 7'b0010010;
                4'h6: hex_to_7seg = 7'b0000010;
                4'h7: hex_to_7seg = 7'b1111000;
                4'h8: hex_to_7seg = 7'b0000000;
                4'h9: hex_to_7seg = 7'b0010000;
                default: hex_to_7seg = 7'b1111111; // blank
            endcase
        end
    endfunction

    // HEX display assignments (active during game)
    reg [6:0] hex0_r, hex1_r, hex2_r, hex3_r, hex4_r, hex5_r;
    
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            hex0_r <= 7'b1111111;
            hex1_r <= 7'b1111111;
            hex2_r <= 7'b1111111;
            hex3_r <= 7'b1111111;
            hex4_r <= 7'b1111111;
            hex5_r <= 7'b1111111;
        end else begin
            if (!timer_running) begin
                // Blank when timer not running
                hex0_r <= 7'b1111111;
                hex1_r <= 7'b1111111;
                hex2_r <= 7'b1111111;
                hex3_r <= 7'b1111111;
                hex4_r <= 7'b1111111;
                hex5_r <= 7'b1111111;
            end else begin
                // Timer on HEX1:HEX0
                hex0_r <= hex_to_7seg(digit_ones);
                hex1_r <= hex_to_7seg(digit_tens);
                
                // Char errors on HEX3:HEX2
                hex2_r <= hex_to_7seg(cerr_ones);
                hex3_r <= hex_to_7seg(cerr_tens);
                
                // Word errors on HEX5:HEX4
                hex4_r <= hex_to_7seg(werr_ones);
                hex5_r <= hex_to_7seg(werr_tens);
            end
        end
    end
    
    assign HEX0 = hex0_r;
    assign HEX1 = hex1_r;
    assign HEX2 = hex2_r;
    assign HEX3 = hex3_r;
    assign HEX4 = hex4_r;
    assign HEX5 = hex5_r;

endmodule

`default_nettype wire