// Test module for scancode_to_fontIndex_new
// Displays received character codes on HEX displays
// HEX3-HEX2: Raw scancode in HEX
// HEX1-HEX0: Character code in DECIMAL
// LEDR: Total count

module test_keyboard(CLOCK_50, KEY, PS2_CLK, PS2_DAT, LEDR, HEX0, HEX1, HEX2, HEX3);
    input wire CLOCK_50;
    input wire [0:0] KEY;
    inout wire PS2_CLK, PS2_DAT;
    output wire [9:0] LEDR;
    output wire [6:0] HEX0;
    output wire [6:0] HEX1;
    output wire [6:0] HEX2;
    output wire [6:0] HEX3;

    wire Resetn;
    wire [7:0] scancode;
    wire ps2_rec;
    wire [7:0] inputChar;
    wire inputChar_rdy;
    
    reg [9:0] Total;  // Count total characters received
    
    assign Resetn = KEY[0];
    
    // PS/2 Receiver module
    ps2_receiver receiver (
        .CLOCK_50(CLOCK_50),
        .Resetn(Resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .scancode(scancode),
        .ps2_rec(ps2_rec)
    );
    
    // Character decoder with key tracking
    scancode_to_fontIndex_new decoder (
        .clock(CLOCK_50),
        .resetn(Resetn),
        .sc(scancode),
        .sc_rdy(ps2_rec),
        .inputChar(inputChar),
        .inputChar_rdy(inputChar_rdy)
    );
    
    // Count total characters
    always @(posedge CLOCK_50) begin
        if (!Resetn)
            Total <= 10'b0;
        else if (inputChar_rdy)
            Total <= Total + 10'b1;
    end
    
    assign LEDR = Total;
    
    // Convert character code (0-49) to decimal digits
    wire [3:0] char_tens;
    wire [3:0] char_ones;
    
    assign char_tens = (inputChar >= 8'd40) ? 4'd4 :
                       (inputChar >= 8'd30) ? 4'd3 :
                       (inputChar >= 8'd20) ? 4'd2 :
                       (inputChar >= 8'd10) ? 4'd1 : 4'd0;
    
    assign char_ones = inputChar - (char_tens * 4'd10);
    
    // Display raw scancode in HEX on HEX3-HEX2
    hex7seg H2 (scancode[3:0], HEX2);
    hex7seg H3 (scancode[7:4], HEX3);
    
    // Display character code in DECIMAL on HEX1-HEX0
    dec7seg D0 (char_ones, HEX0);
    dec7seg D1 (char_tens, HEX1);
    
endmodule

// Seven segment display decoder for HEX (0-F)
module hex7seg (hex, display);
    input wire [3:0] hex;
    output reg [6:0] display;

    /*       0  
     *      ---  
     *     |   |
     *    5|   |1
     *     | 6 |
     *      ---  
     *     |   |
     *    4|   |2
     *     |   |
     *      ---  
     *       3  
     */
    
    always @(hex)
        case (hex)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0011000;
            4'hA: display = 7'b0001000;
            4'hb: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hd: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
        endcase
endmodule

// Seven segment display decoder for DECIMAL (0-9 only)
module dec7seg (dec, display);
    input wire [3:0] dec;
    output reg [6:0] display;

    /*       0  
     *      ---  
     *     |   |
     *    5|   |1
     *     | 6 |
     *      ---  
     *     |   |
     *    4|   |2
     *     |   |
     *      ---  
     *       3  
     */
    
    always @(dec)
        case (dec)
            4'd0: display = 7'b1000000;  // 0
            4'd1: display = 7'b1111001;  // 1
            4'd2: display = 7'b0100100;  // 2
            4'd3: display = 7'b0110000;  // 3
            4'd4: display = 7'b0011001;  // 4
            4'd5: display = 7'b0010010;  // 5
            4'd6: display = 7'b0000010;  // 6
            4'd7: display = 7'b1111000;  // 7
            4'd8: display = 7'b0000000;  // 8
            4'd9: display = 7'b0011000;  // 9
            default: display = 7'b1111111;  // blank for > 9
        endcase
endmodule