// scancode_to_fontIndex.v
// Ignores F0 (break) and E0 (extended). MAKE-only.
// Mapping:
//   0..25  : a..z
//   26..35 : 0..9
//   36     : space
//   37..47 : ` - = [ ] \ ; ' , . /
//   48     : backspace
//   49     : enter

`default_nettype none

module scancode_to_fontIndex (
    input  wire       clock,
    input  wire       resetn,         // active-low
    input  wire [7:0] sc,             // PS/2 byte from receiver
    input  wire       sc_rdy,         // 1-cycle strobe for 'sc'
    output reg  [7:0] inputChar,      // numeric code for font
    output reg        inputChar_rdy   // 1-cycle strobe when inputChar valid
);

    // Flags for break/extended handling
    reg saw_F0;
    reg saw_E0;

    // Combinational decode
    reg [7:0] decoded_code;
    reg       decoded_valid;

    always @* begin
        decoded_code  = 8'd0;
        decoded_valid = 1'b0;

        case (sc)
            // Letters a-z (make codes)
            8'h1C: begin decoded_code = 8'd0;  decoded_valid = 1'b1; end // a
            8'h32: begin decoded_code = 8'd1;  decoded_valid = 1'b1; end // b
            8'h21: begin decoded_code = 8'd2;  decoded_valid = 1'b1; end // c
            8'h23: begin decoded_code = 8'd3;  decoded_valid = 1'b1; end // d
            8'h24: begin decoded_code = 8'd4;  decoded_valid = 1'b1; end // e
            8'h2B: begin decoded_code = 8'd5;  decoded_valid = 1'b1; end // f
            8'h34: begin decoded_code = 8'd6;  decoded_valid = 1'b1; end // g
            8'h33: begin decoded_code = 8'd7;  decoded_valid = 1'b1; end // h
            8'h43: begin decoded_code = 8'd8;  decoded_valid = 1'b1; end // i
            8'h3B: begin decoded_code = 8'd9;  decoded_valid = 1'b1; end // j
            8'h42: begin decoded_code = 8'd10; decoded_valid = 1'b1; end // k
            8'h4B: begin decoded_code = 8'd11; decoded_valid = 1'b1; end // l
            8'h3A: begin decoded_code = 8'd12; decoded_valid = 1'b1; end // m
            8'h31: begin decoded_code = 8'd13; decoded_valid = 1'b1; end // n
            8'h44: begin decoded_code = 8'd14; decoded_valid = 1'b1; end // o
            8'h4D: begin decoded_code = 8'd15; decoded_valid = 1'b1; end // p
            8'h15: begin decoded_code = 8'd16; decoded_valid = 1'b1; end // q
            8'h2D: begin decoded_code = 8'd17; decoded_valid = 1'b1; end // r
            8'h1B: begin decoded_code = 8'd18; decoded_valid = 1'b1; end // s
            8'h2C: begin decoded_code = 8'd19; decoded_valid = 1'b1; end // t
            8'h3C: begin decoded_code = 8'd20; decoded_valid = 1'b1; end // u
            8'h2A: begin decoded_code = 8'd21; decoded_valid = 1'b1; end // v
            8'h1D: begin decoded_code = 8'd22; decoded_valid = 1'b1; end // w
            8'h22: begin decoded_code = 8'd23; decoded_valid = 1'b1; end // x
            8'h35: begin decoded_code = 8'd24; decoded_valid = 1'b1; end // y
            8'h1A: begin decoded_code = 8'd25; decoded_valid = 1'b1; end // z

            // Digits 0-9
            8'h45: begin decoded_code = 8'd26; decoded_valid = 1'b1; end // 0
            8'h16: begin decoded_code = 8'd27; decoded_valid = 1'b1; end // 1
            8'h1E: begin decoded_code = 8'd28; decoded_valid = 1'b1; end // 2
            8'h26: begin decoded_code = 8'd29; decoded_valid = 1'b1; end // 3
            8'h25: begin decoded_code = 8'd30; decoded_valid = 1'b1; end // 4
            8'h2E: begin decoded_code = 8'd31; decoded_valid = 1'b1; end // 5
            8'h36: begin decoded_code = 8'd32; decoded_valid = 1'b1; end // 6
            8'h3D: begin decoded_code = 8'd33; decoded_valid = 1'b1; end // 7
            8'h3E: begin decoded_code = 8'd34; decoded_valid = 1'b1; end // 8
            8'h46: begin decoded_code = 8'd35; decoded_valid = 1'b1; end // 9

            // Space
            8'h29: begin decoded_code = 8'd36; decoded_valid = 1'b1; end // space

            // Punctuation ` - = [ ] \ ; ' , . /
            8'h0E: begin decoded_code = 8'd37; decoded_valid = 1'b1; end // `
            8'h4E: begin decoded_code = 8'd38; decoded_valid = 1'b1; end // -
            8'h55: begin decoded_code = 8'd39; decoded_valid = 1'b1; end // =
            8'h54: begin decoded_code = 8'd40; decoded_valid = 1'b1; end // [
            8'h5B: begin decoded_code = 8'd41; decoded_valid = 1'b1; end // ]
            8'h5D: begin decoded_code = 8'd42; decoded_valid = 1'b1; end // '\'
            8'h4C: begin decoded_code = 8'd43; decoded_valid = 1'b1; end // ;
            8'h52: begin decoded_code = 8'd44; decoded_valid = 1'b1; end // '
            8'h41: begin decoded_code = 8'd45; decoded_valid = 1'b1; end // ,
            8'h49: begin decoded_code = 8'd46; decoded_valid = 1'b1; end // .
            8'h4A: begin decoded_code = 8'd47; decoded_valid = 1'b1; end // /

            // Backspace
            8'h66: begin decoded_code = 8'd48; decoded_valid = 1'b1; end // backspace

            // Enter
            8'h5A: begin decoded_code = 8'd49; decoded_valid = 1'b1; end // enter

            default: begin
                decoded_code  = 8'd0;
                decoded_valid = 1'b0;
            end
        endcase
    end

    // Sequential logic: handle F0/E0 and generate 1-cycle rdy
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            inputChar      <= 8'd0;
            inputChar_rdy  <= 1'b0;
            saw_F0         <= 1'b0;
            saw_E0         <= 1'b0;
        end else begin
            // Default: rdy low every cycle unless we see a valid MAKE
            inputChar_rdy <= 1'b0;

            if (sc_rdy) begin
                if (sc == 8'hF0) begin
                    // BREAK prefix
                    saw_F0 <= 1'b1;
                end else if (sc == 8'hE0) begin
                    // EXTENDED prefix
                    saw_E0 <= 1'b1;
                end else begin
                    // Normal data byte
                    if (!saw_F0 && !saw_E0) begin
                        // This is a MAKE (non-break, non-extended)
                        if (decoded_valid) begin
                            inputChar     <= decoded_code;
                            inputChar_rdy <= 1'b1; // exactly one cycle
                        end
                    end
                    // After using this data byte, clear prefixes
                    saw_F0 <= 1'b0;
                    saw_E0 <= 1'b0;
                end
            end
        end
    end

endmodule