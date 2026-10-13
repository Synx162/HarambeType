`default_nettype none

module main (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,        // KEY[0] = reset (active-low)
    inout  wire        PS2_CLK,
    inout  wire        PS2_DAT,
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK
);

    // --------------------
    // Reset
    // --------------------
    wire resetn = KEY[0];

    // --------------------
    // PS/2 receiver
    // --------------------
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

    // --------------------
    // Scancode -> font index
    // --------------------
    wire [7:0] inputChar;
    wire       inputChar_rdy;

    scancode_to_fontIndex DEC (
        .clock         (CLOCK_50),
        .resetn        (resetn),
        .sc            (scancode),
        .sc_rdy        (sc_rdy),
        .inputChar     (inputChar),
        .inputChar_rdy (inputChar_rdy)
    );

    // char_valid == char_ready from decoder
    wire [4:0] char_index = inputChar[4:0];
    wire       char_valid = inputChar_rdy;

    // --------------------
    // Cursor control
    // --------------------
    localparam integer TEXT_COLS = 40;
    localparam integer TEXT_ROWS = 4;

    reg [9:0] cursor_col;
    reg [9:0] cursor_row;

    wire drawer_busy;
    wire drawer_done;

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            cursor_col <= 10'd0;
            cursor_row <= 10'd0;
        end else begin
            if (drawer_done) begin
                if (cursor_col == (TEXT_COLS - 1)) begin
                    cursor_col <= 10'd0;
                    if (cursor_row == (TEXT_ROWS - 1))
                        cursor_row <= 10'd0;
                    else
                        cursor_row <= cursor_row + 10'd1;
                end else begin
                    cursor_col <= cursor_col + 10'd1;
                end
            end
        end
    end

    // --------------------
    // Font ROM (glyphs)
    // --------------------
    wire [10:0] font_addr;
    wire [8:0]  font_q9;

    font_mem #(
        .n(9),
        .Mn(11),
        .INIT_FILE("font_216_9.mif")
    ) FONT_ROM (
        .address (font_addr),
        .clock   (CLOCK_50),
        .q       (font_q9)
    );

    // --------------------
    // Char -> Pixel drawer
    // --------------------
    wire [9:0] draw_x;
    wire [8:0] draw_y;
    wire [8:0] draw_color;
    wire       draw_write;

    char_to_pixel_draw CHAR_DRAW (
        .char_index   (char_index),
        .char_valid   (char_valid),
        .clock        (CLOCK_50),
        .resetn       (resetn),
        .cursor_col   (cursor_col),
        .cursor_row   (cursor_row),
        .busy         (drawer_busy),
        .done         (drawer_done),
        .font_address (font_addr),
        .font_color9  (font_q9),
        .x            (draw_x),
        .y            (draw_y),
        .color        (draw_color),
        .write        (draw_write)
    );

    // --------------------
    // VGA adapter (background from its own MIF)
    // --------------------
    wire [9:0] vga_x     = draw_x;
    wire [8:0] vga_y     = draw_y;
    wire [8:0] vga_color = draw_color;
    wire       vga_write = draw_write;

    vga_adapter #(
        .RESOLUTION       ("640x480"),
        .COLOR_DEPTH      (9),
        .BACKGROUND_IMAGE ("background_640_9.mif")
    ) VGA (
        .resetn      (resetn),
        .clock       (CLOCK_50),
        .color       (vga_color),
        .x           (vga_x),
        .y           (vga_y),
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

endmodule

`default_nettype wire
