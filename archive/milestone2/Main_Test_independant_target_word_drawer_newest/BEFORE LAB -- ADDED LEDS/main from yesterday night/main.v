module main (CLOCK_50, KEY, PS2_CLK, PS2_DAT, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    input  wire CLOCK_50;
    input  wire [3:0]KEY;        // KEY[0] = reset, KEY[1] = preload trigger (active-low)
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
        .ps2_rec   (sc_rdy)
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
    reg        kb_char_valid_pulse;

    // separate busy/done for kb + preload, then combine into drawer_busy/done
    wire drawer_busy_kb;
    wire drawer_done_kb;
    wire drawer_busy_pre;
    wire drawer_done_pre;
    wire drawer_busy;
    wire drawer_done;

    wire kb_char_valid_edge = kb_char_valid & ~kb_char_valid_d; // rising edge detect

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            kb_char_valid_d      <= 1'b0;
            kb_char_valid_pulse  <= 1'b0;
            kb_char_reg          <= 5'd0;
        end else begin
            kb_char_valid_d      <= kb_char_valid;
            kb_char_valid_pulse  <= 1'b0;  // default

            // accept new key only when drawer idle, not preloading, not clearing
            if (kb_char_valid_edge && !drawer_busy && !preload_mode && !clearing) begin
                kb_char_reg         <= kb_char_index;
                kb_char_valid_pulse <= 1'b1;
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

    parameter MIN_PRELOAD_CHARS = 150;

    // Cursor control for keyboard typing
    parameter TEXT_COLS = 34;
    parameter TEXT_ROWS = 5;

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
                // start preload on KEY1 press when not clearing
                if (key1_pressed && !clearing) begin
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

    // track previous preload_mode for test-start pulse
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            preload_mode_prev <= 1'b0;
        end else begin
            preload_mode_prev <= preload_mode;
        end
    end

    // goes high for one cycle when preload finishes -> start of typing test
    wire start_new_test_pulse = preload_mode_prev & ~preload_mode;

    parameter BACKGROUND_COLOR = 9'b000000000;

    // Font ROM (letters)
    wire [10:0] font_addr_kb;
    wire [10:0] font_addr_pre;
    wire [10:0] font_addr;
    wire [8:0]  font_q9;

    font_mem #(.n(9), .Mn(11), .INIT_FILE("font_216_9.mif")) 
    FONT_ROM (.address (font_addr), .clock(CLOCK_50), .q(font_q9));

    assign font_addr = preload_mode ? font_addr_pre : font_addr_kb;

    // Digit ROM (numbers for counter)
    wire [9:0] num_addr;
    wire [8:0] num_q9;

    num_mem #(.n(9), .Mn(10), .INIT_FILE("numbers_80_9.mif"))
    NUM_ROM (
        .address (num_addr),
        .clock   (CLOCK_50),
        .q       (num_q9)
    );

    // countdown timer for typing test (15 -> 0 seconds)
    wire [3:0] timer_value;
    wire       timer_expired;
    wire       timer_update_raw;   // 1 Hz pulse from timer

    countdown_timer TIMER (
        .clock        (CLOCK_50),
        .resetn       (resetn),
        .start        (~KEY[2]), // start timer when new test begins (changed from start_new_test_pulse to ~KEY2)
        .timer_value  (timer_value),
        .timer_expired(timer_expired),
        .update_pulse (timer_update_raw)
    );

    // split timer_value (0..15) into tens/ones digits for drawing
    reg [3:0] digit_tens;
    reg [3:0] digit_ones;

    always @(*) begin
        if (timer_value >= 4'd10) begin
            digit_tens = 4'd1;
            digit_ones = timer_value - 4'd10;
        end else begin
            digit_tens = 4'd0;
            digit_ones = timer_value;
        end
    end

    // simple handshake so we don't lose timer updates while number drawer is busy
    wire       num_busy;
    wire       num_done;
    reg        num_start_pending;
    reg        num_start_pulse;

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            num_start_pending <= 1'b0;
            num_start_pulse   <= 1'b0;
        end else begin
            num_start_pulse <= 1'b0;

            // latch 1 Hz tick from timer
            if (timer_update_raw)
                num_start_pending <= 1'b1;

            // fire draw pulse once drawer is idle and screen not clearing
            if (num_start_pending && !num_busy && !clearing) begin
                num_start_pulse   <= 1'b1;
                num_start_pending <= 1'b0;
            end
        end
    end

    // fixed cursor for counter box (uses internal H_MARGIN/V_MARGIN in num_to_pixel_draw)
    wire [9:0] counter_cursor_col = 10'd0;
    wire [9:0] counter_cursor_row = 10'd0;

    // target_words instance
    target_words TARGET_WORDS (
        .clock       (CLOCK_50),
        .resetn      (resetn),
        .enable_send (tw_enable),
        .char_sent   (tw_char_sent),
        .letter_ready(tw_letter_ready)
    );

    // Parameters shared with done_list/comparator word storage
    localparam N_LETTERS = 8;
    localparam N_WORDS   = 40;
    localparam N_TOTAL   = N_LETTERS * N_WORDS;

    // Flattened word list from done_list for comparator (5 bits per char * N_TOTAL chars)
    wire [5*N_TOTAL-1:0] done_words_flat;
    wire [15:0]          char_errors;
    wire [15:0]          word_errors;

    // Capture target words into done_list during preload
    done_list DONE_LIST (
        .clock       (CLOCK_50),
        .resetn      (resetn),
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
        .start_new_test   (start_new_test_pulse),
        .typed_char       (kb_char_reg),
        .typed_char_valid (kb_char_valid_pulse & ~preload_mode & ~clearing),
        .words_flat       (done_words_flat),
        .char_errors      (char_errors),
        .word_errors      (word_errors)
    );

    // DRAWERS
	
    // Keyboard drawer outputs
    wire [9:0] draw_x_kb;
    wire [8:0] draw_y_kb;
    wire [8:0] draw_color_kb;
    wire       draw_write_kb;

    // Preload drawer outputs
    wire [9:0] draw_x_pre;
    wire [8:0] draw_y_pre;
    wire [8:0] draw_color_pre;
    wire       draw_write_pre;

    // Counter drawer outputs
    wire [9:0] draw_x_num;
    wire [8:0] draw_y_num;
    wire [8:0] draw_color_num;
    wire       draw_write_num;

    // Keyboard drawer: uses bottom text box
    char_to_pixel_draw CHAR_DRAW (
        .char_index   (kb_char_reg),
        .char_valid   (kb_char_valid_pulse & ~clearing & ~preload_mode),
        .clock        (CLOCK_50),
        .resetn       (resetn),
        .cursor_col   (cursor_col),
        .cursor_row   (cursor_row),
        .busy         (drawer_busy_kb),
        .done         (drawer_done_kb),
        .font_address (font_addr_kb),
        .font_color9  (font_q9),
        .x            (draw_x_kb),
        .y            (draw_y_kb),
        .color        (draw_color_kb),
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
        .font_color9  (font_q9),
        .x            (draw_x_pre),
        .y            (draw_y_pre),
        .color        (draw_color_pre),
        .write        (draw_write_pre)
    );

    // Counter drawer: draws remaining time using num_mem
    num_to_pixel_draw TIMER_DRAW (
        .digit0      (digit_ones),          // rightmost digit
        .digit1      (digit_tens),
        .digit2      (4'd0),
        .digit3      (4'd0),
        .num_digits  (3'd2),                // draw 2 digits
        .num_valid   (num_start_pulse),
        .clock       (CLOCK_50),
        .resetn      (resetn),
        .cursor_col  (counter_cursor_col),
        .cursor_row  (counter_cursor_row),
        .busy        (num_busy),
        .done        (num_done),
        .num_address (num_addr),
        .num_color9  (num_q9),
        .x           (draw_x_num),
        .y           (draw_y_num),
        .color       (draw_color_num),
        .write       (draw_write_num)
    );

    // Text draw mux (kb vs preload)
    wire [9:0] draw_x_text;
    wire [8:0] draw_y_text;
    wire [8:0] draw_color_text;
    wire       draw_write_text;

    assign draw_x_text     = preload_mode ? draw_x_pre     : draw_x_kb;
    assign draw_y_text     = preload_mode ? draw_y_pre     : draw_y_kb;
    assign draw_color_text = preload_mode ? draw_color_pre : draw_color_kb;
    assign draw_write_text = preload_mode ? draw_write_pre : draw_write_kb;

    // Combined draw: timer counter has priority when it is writing a pixel
    wire [9:0] draw_x;
    wire [8:0] draw_y;
    wire [8:0] draw_color;
    wire       draw_write;

    assign draw_x     = draw_write_num ? draw_x_num     : draw_x_text;
    assign draw_y     = draw_write_num ? draw_y_num     : draw_y_text;
    assign draw_color = draw_write_num ? draw_color_num : draw_color_text;
    assign draw_write = draw_write_num ? 1'b1           : draw_write_text;

    // LOGIC FOR CLEARING

    reg        clearing;
    reg [1:0]  box_id;
    reg [1:0]  max_box_id;
    reg [9:0]  clear_x;
    reg [8:0]  clear_y;
    reg [9:0]  box_x0;
    reg [8:0]  box_y0;
    reg [9:0]  box_w;
    reg [8:0]  box_h;

    // choose which text box to clear
    always @(*) begin
        case (box_id)
            2'd0: begin
                // bottom typing box
                box_x0 = 10'd50;
                box_y0 = 9'd280;
                box_w  = 10'd544;
                box_h  = 9'd80;
            end
            2'd1: begin
                // top preload/target box
                box_x0 = 10'd50;
                box_y0 = 9'd145;
                box_w  = 10'd544;
                box_h  = 9'd80;
            end
            2'd2: begin
                // counter box (timer digits near top-right)
                box_x0 = 10'd540;
                box_y0 = 9'd20;
                box_w  = 10'd80;
                box_h  = 9'd40;
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
            box_id     <= 2'd0;
            max_box_id <= 2'd2;      // boxes 0, 1 & 2
            clear_x    <= 10'd0;
            clear_y    <= 9'd0;
        end else begin
            // on wrap, clear only typing box (0)
            if (wrapped_back && !clearing) begin
                clearing   <= 1'b1;
                box_id     <= 2'd0;
                max_box_id <= 2'd0;
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
                            box_id <= box_id + 2'd1;
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
    wire [8:0] vga_color;
    wire       vga_write;

    assign vga_x     = clearing ? (box_x0 + clear_x) : draw_x;
    assign vga_y     = clearing ? (box_y0 + clear_y) : draw_y;
    assign vga_color = clearing ? BACKGROUND_COLOR   : draw_color;
    assign vga_write = clearing ? 1'b1               : draw_write;

    // VGA adapter
    vga_adapter VGA (
        .resetn      (resetn),
        .clock       (CLOCK_50),
        .x           (vga_x),
        .y           (vga_y),
        .color       (vga_color),
        .write        (vga_write),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

endmodule

`default_nettype wire
