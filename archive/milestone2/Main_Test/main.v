module main (CLOCK_50, KEY, PS2_CLK, PS2_DAT, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    input  wire CLOCK_50;
    input  wire [3:0]KEY;        // KEY[0] = reset
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

    ps2_receiver PS2_RX (.CLOCK_50 (CLOCK_50),.Resetn (resetn),.PS2_CLK (PS2_CLK),.PS2_DAT  (PS2_DAT),.scancode (scancode),.ps2_rec  (sc_rdy));

    // Scancode -> font index
    wire [7:0] inputChar;
    wire       inputChar_rdy;

    scancode_to_fontIndex DEC (.clock(CLOCK_50),.resetn(resetn),.sc(scancode),.sc_rdy(sc_rdy),.inputChar(inputChar),.inputChar_rdy(inputChar_rdy));

    // keyboard char path
    wire [4:0] kb_char_index = inputChar[4:0]; // added
    wire       kb_char_valid = inputChar_rdy;  // added

    // target_words interface
    wire [4:0] tw_char_sent;       // added
    wire       tw_letter_ready;    // added
    reg        tw_enable;          // added

    // muxed inputs to CHAR_DRAW
    wire [4:0] char_index_in;      // added
    wire       char_valid_in;      // added
    wire [9:0] cursor_col_in;      // added
    wire [9:0] cursor_row_in;      // added

    // preload controller
    reg        preload_mode;       // added
    reg [7:0]  preload_count;      // added
    reg [9:0]  preload_col;        // added
    reg [9:0]  preload_row;        // added

    // latch for target_words outputs
    reg [4:0]  tw_char_reg;        // added
    reg        tw_valid_reg;       // added

    // preload FSM state
    localparam [1:0] PR_IDLE = 2'd0,        // added
                     PR_WAIT_LETTER = 2'd1, // added
                     PR_WAIT_DONE   = 2'd2; // added
    reg [1:0] preload_state;               // added

    localparam integer TOTAL_PRELOAD_CHARS = 160; // added

    // Cursor control
    localparam integer TEXT_COLS = 34;
    localparam integer TEXT_ROWS = 5;

    reg [9:0] cursor_col;
    reg [9:0] cursor_row;

    wire drawer_busy;
    wire drawer_done;
    reg wrapped_back; // detect when we wrap to help with clearing

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            cursor_col   <= 10'd0;
            cursor_row   <= 10'd0;
            wrapped_back <= 1'b0;
        end else begin
            wrapped_back <= 1'b0;
            
            if (drawer_done && !preload_mode) begin // added
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
    always @(posedge CLOCK_50 or negedge resetn) begin // added
        if (!resetn) begin                             // added
            preload_mode   <= 1'b1;                    // added
            preload_state  <= PR_IDLE;                 // added
            preload_count  <= 8'd0;                    // added
            preload_col    <= 10'd0;                   // added
            preload_row    <= 10'd0;                   // added
            tw_enable      <= 1'b0;                    // added
            tw_char_reg    <= 5'd0;                    // added
            tw_valid_reg   <= 1'b0;                    // added
        end else begin                                 // added
            tw_enable    <= 1'b0;                      // added
            tw_valid_reg <= 1'b0;                      // added

            if (preload_mode) begin                    // added
                if (preload_count == TOTAL_PRELOAD_CHARS) begin // added
                    preload_mode  <= 1'b0;             // added
                    preload_state <= PR_IDLE;          // added
                end else if (!clearing) begin          // added
                    case (preload_state)               // added
                        PR_IDLE: begin                 // added
                            if (!drawer_busy) begin    // added
                                tw_enable     <= 1'b1; // ask target_words for next char // added
                                preload_state <= PR_WAIT_LETTER; // added
                            end                        // added
                        end                            // added

                        PR_WAIT_LETTER: begin          // added
                            if (tw_letter_ready) begin // added
                                tw_char_reg  <= tw_char_sent; // latch letter // added
                                tw_valid_reg <= 1'b1;         // 1-cycle char_valid pulse // added

                                preload_count <= preload_count + 1'b1; // added
                                if (preload_col == (TEXT_COLS - 1)) begin // added
                                    preload_col <= 10'd0;      // added
                                    preload_row <= preload_row + 10'd1; // added
                                end else begin                 // added
                                    preload_col <= preload_col + 10'd1; // added
                                end                            // added

                                preload_state <= PR_WAIT_DONE; // added
                            end                                // added
                        end                                    // added

                        PR_WAIT_DONE: begin                    // added
                            if (drawer_done) begin             // added
                                preload_state <= PR_IDLE;      // added
                            end                                // added
                        end                                    // added

                        default: begin                         // added
                            preload_state <= PR_IDLE;          // added
                        end                                    // added
                    endcase                                    // added
                end                                            // added
            end                                                // added
        end                                                    // added
    end                                                        // added

    parameter BACKGROUND_COLOR = 9'b000000000;
    
    // Font ROM (letters)
    wire [10:0] font_addr;
    wire [8:0]  font_q9;
    
    // Font ROM (numbers)
    //wire [9:0] num_addr;
    //wire [8:0] num_q9;

    font_mem #(.n(9),.Mn(11),.INIT_FILE("font_216_9.mif")) 
    FONT_ROM (.address (font_addr),.clock (CLOCK_50),.q (font_q9));
    // need to instantiate for digits

    // target_words instance
    target_words TARGET_WORDS (            // added
        .clock       (CLOCK_50),           // added
        .resetn      (resetn),             // added
        .enable_send (tw_enable),          // added
        .char_sent   (tw_char_sent),       // added
        .letter_ready(tw_letter_ready)     // added
    );                                     // added

    // Char -> Pixel drawer
    wire [9:0]draw_x;
    wire [8:0]draw_y;
    wire [8:0]draw_color;
    wire draw_write;

    // mux for drawer inputs
    assign char_index_in = preload_mode ? tw_char_reg   : kb_char_index; // added
    assign char_valid_in = preload_mode ? tw_valid_reg  : kb_char_valid; // added
    assign cursor_col_in = preload_mode ? preload_col   : cursor_col;    // added
    assign cursor_row_in = preload_mode ? preload_row   : cursor_row;    // added

    char_to_pixel_draw CHAR_DRAW (
        .char_index(char_index_in),                 // added
        .char_valid(char_valid_in & ~clearing),     // added
        .clock(CLOCK_50),
        .resetn(resetn),
        .cursor_col(cursor_col_in),                 // added
        .cursor_row(cursor_row_in),                 // added
        .busy(drawer_busy),
        .done(drawer_done),
        .font_address(font_addr),
        .font_color9(font_q9),
        .x(draw_x),
        .y(draw_y),
        .color(draw_color),
        .write(draw_write)
    );
    
    // need to instantiate for digits
    
    // LOGIC FOR CLEARING
    reg clearing;    // set to 1 while we are erasing
    reg [1:0] box_id;   // number of the box we are clearing (until 4)
    reg [9:0] clear_x;
    reg [8:0] clear_y;  // size is to match the screen
    reg [9:0] box_x0;  // this and the next tell me where my specific box starts
    reg [8:0] box_y0;
    reg [9:0] box_w;   // this and next tell me dimensions of text box
    reg [8:0] box_h;
    
    parameter integer NUM_OF_BOXES = 1; // only d\for testing
    
    // decode which box is to be cleared
    always @(*) begin    
        case (box_id)
            2'b00 : begin
                box_x0 = 50; // in pixels
                box_y0 = 280; // in pixels
                box_w  = 320;// in pixels
                box_h  = 32;// in pixels
            end
            2'b01: begin
                box_x0 =0;
                box_y0 =0;
                box_w  =1;
                box_h  =1;
            end
            2'b10: begin
                box_x0 =0;
                box_y0 =0;
                box_w  =1;
                box_h  =1;
            end
            2'b11: begin
                box_x0 =0;
                box_y0 =0;
                box_w  =1;
                box_h  =1;
            end
        endcase
    end
    
    // clear screen FSM (reset)
    
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            clearing <= 1'b1;      // on reset do one full clear
            box_id   <= 2'd0;
            clear_x  <= 10'd0;
            clear_y  <= 9'd0;
        end else begin
            // Start a new clear pass when we wrap back and aren't already clearing
            if (wrapped_back && !clearing) begin
                clearing <= 1'b1;
                box_id   <= 2'd0;
                clear_x  <= 10'd0;
                clear_y  <= 9'd0;
            end else if (clearing) begin
                // scanning logic
                if (clear_x == (box_w - 1)) begin
                    clear_x <= 10'd0;

                    if (clear_y == (box_h - 1)) begin
                        clear_y <= 9'd0;

                        if (box_id == (NUM_OF_BOXES - 1)) begin
                            clearing <= 1'b0;       // finished all boxes
                        end else begin
                            box_id <= box_id + 2'd1; // next box
                        end
                    end else begin
                        clear_y <= clear_y + 9'd1;  // next row in current box
                    end
                end else begin
                    clear_x <= clear_x + 10'd1;      // next column
                end
            end
        end
    end


    // VGA adapter (background from its own MIF)
    wire [9:0]vga_x;
    wire [8:0]vga_y;
    wire [8:0]vga_color;
    wire vga_write;
    
    // if statements to assign the inputs to the vga (clear/draw)
    assign vga_x = clearing ? (box_x0 + clear_x) : draw_x;
    assign vga_y = clearing ? (box_y0 + clear_y) : draw_y;
    assign vga_color = clearing ? BACKGROUND_COLOR : draw_color;
    assign vga_write = clearing ? 1'b1 : draw_write;

    vga_adapter #(
        .RESOLUTION("640x480"),
        .COLOR_DEPTH(9),
        .BACKGROUND_IMAGE("background_640_9.mif")
    ) VGA (
        .resetn(resetn),
        .clock(CLOCK_50),
        .color(vga_color),
        .x(vga_x),
        .y(vga_y),
        .write(vga_write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );

endmodule

`default_nettype wire
