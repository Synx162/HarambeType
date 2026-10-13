// Simplified PS/2 scancode decoder with proper BREAK filtering
// Works with extended pulse from ps2_receiver

module scancode_to_fontIndex(clock, resetn, sc, sc_rdy, inputChar, inputChar_rdy);
    input  wire       clock;
    input  wire       resetn;
    input  wire [7:0] sc;            // PS/2 scancode
    input  wire       sc_rdy;        // extended pulse (20 cycles)
    output reg  [7:0] inputChar;     // character code (0-49)
    output reg        inputChar_rdy; // pulse when valid

    // Track if we just saw an F0 (BREAK prefix)
    reg saw_F0;
    reg saw_E0;
    
    // Decode scancode to character code (combinational)
    reg [7:0] code;
    
    always @(*) begin
        code = 8'hFF;  // Default to invalid
        
        case (sc)
            // Letters a-z map to 0-25
            8'h1C: code = 8'd0;   // a
            8'h32: code = 8'd1;   // b
            8'h21: code = 8'd2;   // c
            8'h23: code = 8'd3;   // d
            8'h24: code = 8'd4;   // e
            8'h2B: code = 8'd5;   // f
            8'h34: code = 8'd6;   // g
            8'h33: code = 8'd7;   // h
            8'h43: code = 8'd8;   // i
            8'h3B: code = 8'd9;   // j
            8'h42: code = 8'd10;  // k
            8'h4B: code = 8'd11;  // l
            8'h3A: code = 8'd12;  // m
            8'h31: code = 8'd13;  // n
            8'h44: code = 8'd14;  // o
            8'h4D: code = 8'd15;  // p
            8'h15: code = 8'd16;  // q
            8'h2D: code = 8'd17;  // r
            8'h1B: code = 8'd18;  // s
            8'h2C: code = 8'd19;  // t
            8'h3C: code = 8'd20;  // u
            8'h2A: code = 8'd21;  // v
            8'h1D: code = 8'd22;  // w
            8'h22: code = 8'd23;  // x
            8'h35: code = 8'd24;  // y
            8'h1A: code = 8'd25;  // z
            
            // Space maps to 26
            8'h29: code = 8'd26;  // space
            
            // Digits 0-9 map to 27-36
            8'h45: code = 8'd27;  // 0
            8'h16: code = 8'd28;  // 1
            8'h1E: code = 8'd29;  // 2
            8'h26: code = 8'd30;  // 3
            8'h25: code = 8'd31;  // 4
            8'h2E: code = 8'd32;  // 5
            8'h36: code = 8'd33;  // 6
            8'h3D: code = 8'd34;  // 7
            8'h3E: code = 8'd35;  // 8
            8'h46: code = 8'd36;  // 9
            
            // Punctuation maps to 37-47
            8'h0E: code = 8'd37;  // ` (backtick)
            8'h4E: code = 8'd38;  // - (minus)
            8'h55: code = 8'd39;  // = (equals)
            8'h54: code = 8'd40;  // [ (left bracket)
            8'h5B: code = 8'd41;  // ] (right bracket)
            8'h5D: code = 8'd42;  // \ (backslash)
            8'h4C: code = 8'd43;  // ; (semicolon)
            8'h52: code = 8'd44;  // ' (apostrophe)
            8'h41: code = 8'd45;  // , (comma)
            8'h49: code = 8'd46;  // . (period)
            8'h4A: code = 8'd47;  // / (slash)
            
            // Special action keys
            8'h66: code = 8'd48;  // backspace
            8'h5A: code = 8'd49;  // enter
            
            default: code = 8'hFF;
        endcase
    end

    // Detect rising edge of sc_rdy
    reg sc_rdy_prev;
    wire sc_rdy_rising;
    
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            sc_rdy_prev <= 1'b0;
        end else begin
            sc_rdy_prev <= sc_rdy;
        end
    end
    
    assign sc_rdy_rising = sc_rdy && !sc_rdy_prev;

    // State machine to track F0 and E0 prefixes
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            saw_F0 <= 1'b0;
            saw_E0 <= 1'b0;
            inputChar <= 8'd0;
            inputChar_rdy <= 1'b0;
        end else begin
            inputChar_rdy <= 1'b0;  // default: no pulse
            
            if (sc_rdy_rising) begin
                if (sc == 8'hF0) begin
                    // BREAK prefix - next scancode is a key release, ignore it
                    saw_F0 <= 1'b1;
                end else if (sc == 8'hE0) begin
                    // Extended prefix - ignore extended keys
                    saw_E0 <= 1'b1;
                end else if (saw_F0) begin
                    // This is a BREAK code (key release), ignore it
                    saw_F0 <= 1'b0;
                    saw_E0 <= 1'b0;  // reset both flags
                end else if (saw_E0) begin
                    // This is an extended key, ignore it
                    saw_E0 <= 1'b0;
                    saw_F0 <= 1'b0;  // reset both flags
                end else begin
                    // Normal MAKE code (key press)
                    if (code != 8'hFF) begin
                        inputChar <= code;
                        inputChar_rdy <= 1'b1;  // pulse for 1 cycle
                    end
                    saw_F0 <= 1'b0;
                    saw_E0 <= 1'b0;
                end
            end
        end
    end

endmodule

// EXPLANATION:
// -----------
// This version properly filters BREAK codes:
// 
// Keyboard sequence when you press and release 'a':
//   1. 0x1C (MAKE - key press) → we output this
//   2. 0xF0 (BREAK prefix) → we set saw_F0 flag
//   3. 0x1C (BREAK - key release) → we see saw_F0 is set, so ignore
//
// The saw_F0 flag prevents us from processing the same scancode twice