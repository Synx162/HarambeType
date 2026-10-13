// Main top-level module for ps2-testing (NEWEST WORKING)
// Shows the PS/2 scancode on HEX5-HEX4 and decoded character on HEX1-HEX0

module main(CLOCK_50, KEY, PS2_CLK, PS2_DAT, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);
    input  wire       CLOCK_50;    // 50 MHz clock
    input  wire [0:0] KEY;         // KEY[0] is reset (active-low when pressed)
    inout  wire       PS2_CLK;     // PS/2 clock line
    inout  wire       PS2_DAT;     // PS/2 data line
    output wire [6:0] HEX0;        // Rightmost display - decoded char low nibble
    output wire [6:0] HEX1;        // decoded char high nibble
    output wire [6:0] HEX2;        // unused
    output wire [6:0] HEX3;        // unused
    output wire [6:0] HEX4;        // scancode low nibble
    output wire [6:0] HEX5;        // Leftmost display - scancode high nibble

    // Reset signal (active-low)
    wire Resetn;
    assign Resetn = KEY[0];

    // Wires connecting PS/2 receiver to scancode decoder
    wire [7:0] scancode;      // Raw PS/2 scancode byte
    wire       ps2_rec;       // Pulse when scancode is ready

    // Wires from scancode decoder
    wire [7:0] decoded_char;  // Decoded character code (0-49)
    wire       char_ready;    // Pulse when decoded character is ready

    // Registers to hold the last received values for display
    reg [7:0] last_scancode;   // Last scancode received
    reg [7:0] last_decoded;    // Last decoded character


    // Instantiate PS/2 Receiver

    // This module receives raw scancodes from the keyboard
    ps2_receiver ps2_rx (
        .CLOCK_50(CLOCK_50),
        .Resetn(Resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .scancode(scancode),    // Output: raw scancode byte
        .ps2_rec(ps2_rec)       // Output: pulse when byte ready
    );

    // =========================================================================
    // Instantiate Scancode to Character Decoder
    // =========================================================================
    // This module converts PS/2 scancodes to character codes (0-49)
    scancode_to_fontIndex decoder (
        .clock(CLOCK_50),
        .resetn(Resetn),
        .sc(scancode),          // Input: scancode from PS/2 receiver
        .sc_rdy(ps2_rec),       // Input: pulse when scancode ready
        .inputChar(decoded_char), // Output: decoded character (0-49)
        .inputChar_rdy(char_ready) // Output: pulse when character ready
    );

    // =========================================================================
    // Latch BOTH scancode and decoded character together
    // =========================================================================
    // IMPORTANT: We latch both on char_ready so they update at the same time!
    // This prevents the display lag where one updates before the other.
    // We latch the scancode value that corresponds to the decoded character.
    always @(posedge CLOCK_50) begin
        if (!Resetn) begin
            last_scancode <= 8'd0;
            last_decoded <= 8'd0;
        end else begin
            if (char_ready) begin
                last_scancode <= scancode;      // Latch scancode
                last_decoded <= decoded_char;   // Latch decoded character
                // Both update together on same cycle
            end
        end
    end

    // =========================================================================
    // Connect to 7-segment displays
    // =========================================================================
    // HEX5-HEX4: Show raw scancode (2 hex digits)
    // HEX1-HEX0: Show decoded character (2 hex digits)
    // HEX3-HEX2: Unused (display OFF)

    // Display raw scancode on HEX5-HEX4
    hex7seg hex5_display (.hex(last_scancode[7:4]), .display(HEX5));  
    hex7seg hex4_display (.hex(last_scancode[3:0]), .display(HEX4));  

    // Display decoded character on HEX1-HEX0
    hex7seg hex1_display (.hex(last_decoded[7:4]), .display(HEX1));   
    hex7seg hex0_display (.hex(last_decoded[3:0]), .display(HEX0));   

    assign HEX3 = 7'b1111111;  // All segments off
    assign HEX2 = 7'b1111111;  // All segments off

endmodule


// 7-Segment Display Decoder hexadecimal

module hex7seg(hex, display);
    input  wire [3:0] hex;      // 4-bit input (0-15)
    output reg  [6:0] display;  // 7-segment output

    // Segment layout:
    //      0
    //     ---
    //   5|   |1
    //     -6-
    //   4|   |2
    //     ---
    //      3

    always @(*) begin
        case (hex)
            4'h0: display = 7'b1000000;  // 0
            4'h1: display = 7'b1111001;  // 1
            4'h2: display = 7'b0100100;  // 2
            4'h3: display = 7'b0110000;  // 3
            4'h4: display = 7'b0011001;  // 4
            4'h5: display = 7'b0010010;  // 5
            4'h6: display = 7'b0000010;  // 6
            4'h7: display = 7'b1111000;  // 7
            4'h8: display = 7'b0000000;  // 8
            4'h9: display = 7'b0011000;  // 9
            4'hA: display = 7'b0001000;  // A
            4'hB: display = 7'b0000011;  // b
            4'hC: display = 7'b1000110;  // C
            4'hD: display = 7'b0100001;  // d
            4'hE: display = 7'b0000110;  // E
            4'hF: display = 7'b0001110;  // F
            default: display = 7'b1111111;  
        endcase
    end

endmodule