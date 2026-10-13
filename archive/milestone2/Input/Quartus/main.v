module main(CLOCK_50, KEY, PS2_CLK, PS2_DAT, LEDR, HEX0, HEX1, HEX2, HEX3);
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
    
    reg [9:0] Total;
    
    assign Resetn = KEY[0];
    
    ps2_receiver receiver (
        .CLOCK_50(CLOCK_50),
        .Resetn(Resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .scancode(scancode),
        .ps2_rec(ps2_rec)
    );
    
    scancode_to_fontIndex decoder (
        .clock(CLOCK_50),
        .resetn(Resetn),
        .sc(scancode),
        .sc_rdy(ps2_rec),
        .inputChar(inputChar),
        .inputChar_rdy(inputChar_rdy)
    );
    
    always @(posedge CLOCK_50) begin
        if (!Resetn)
            Total <= 10'd0;
        else if (inputChar_rdy)
            Total <= Total + 10'd1;
    end
    
    assign LEDR = Total;
    
    // Direct display - NO latching
    wire [3:0] char_tens;
    wire [3:0] char_ones;
    
    assign char_tens = (inputChar >= 8'd40) ? 4'd4 :
                       (inputChar >= 8'd30) ? 4'd3 :
                       (inputChar >= 8'd20) ? 4'd2 :
                       (inputChar >= 8'd10) ? 4'd1 : 4'd0;
    
    assign char_ones = inputChar - (char_tens * 4'd10);
    
    hex7seg H2 (scancode[3:0], HEX2);
    hex7seg H3 (scancode[7:4], HEX3);
    hex7seg D0 (char_ones, HEX0);
    hex7seg D1 (char_tens, HEX1);
    
endmodule

module hex7seg (hex, display);
    input wire [3:0] hex;
    output reg [6:0] display;
    
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