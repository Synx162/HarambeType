// scancode_to_fontIndex.v
// MAKE-only decoder: ignores F0 (break) and E0 (extended).
// No Shift/Caps.
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
    input  wire       resetn,       // active-low
    input  wire [7:0] sc,           // PS/2 data byte (from PS/2 core)
    input  wire       sc_rdy,       // pulse from PS/2 core when 'sc' valid
    output reg  [7:0] inputChar,    // decoded numeric code
    output reg        inputChar_rdy // 1-cycle pulse when inputChar valid
);

    // =========================================================================
    // Synchronize sc_rdy to 'clock' and make a clean 1-cycle strobe.
    // Then latch 'sc' on that strobe so decoding sees a stable byte.
    // =========================================================================
    reg rdy_meta, rdy_sync, rdy_sync_d;
    always @(posedge clock) begin
        if (!resetn) begin
            rdy_meta   <= 1'b0;
            rdy_sync   <= 1'b0;
            rdy_sync_d <= 1'b0;
        end else begin
            rdy_meta   <= sc_rdy;    // 2-FF sync for the strobe
            rdy_sync   <= rdy_meta;
            rdy_sync_d <= rdy_sync;
        end
    end

    wire sc_strobe = rdy_sync & ~rdy_sync_d; // rising edge detect, 1 cycle

    reg [7:0] sc_byte; // latched scancode (stable in our domain)
    always @(posedge clock) begin
        if (!resetn) sc_byte <= 8'h00;
        else if (sc_strobe)  sc_byte <= sc;
    end

    // Handy flags on the latched byte
    wire is_F0 = (sc_byte == 8'hF0); // break prefix
    wire is_E0 = (sc_byte == 8'hE0); // extended prefix

    // =========================================================================
    // FSM to swallow F0/E0 sequences; pass through only plain MAKE bytes.
    // =========================================================================
    localparam [1:0] S_BASE    = 2'd0,
                     S_GOTF0   = 2'd1,
                     S_GOTE0   = 2'd2,
                     S_GOTE0F0 = 2'd3;

    reg [1:0] y, Y;

    // Next-state
    always @(*) begin
        Y = y; // hold by default
        if (sc_strobe) begin
            case (y)
                S_BASE: begin
                    if (is_F0)      Y = S_GOTF0;
                    else if (is_E0) Y = S_GOTE0;
                    else            Y = S_BASE;
                end
                S_GOTF0:   Y = S_BASE;     // consume 1 data byte after F0
                S_GOTE0:   Y = is_F0 ? S_GOTE0F0 : S_BASE;
                S_GOTE0F0: Y = S_BASE;     // consume 1 data byte after E0 F0
                default:   Y = S_BASE;
            endcase
        end
    end

    // State FFs
    always @(posedge clock) begin
        if (!resetn) y <= S_BASE;
        else         y <= Y;
    end

    // =========================================================================
    // Decoder: sc_byte -> code_num_d (mapping table)
    // =========================================================================
    reg [7:0] code_num_d;
    always @(*) begin
        code_num_d = 8'hFF; // default = invalid
        case (sc_byte)
            // letters a..z → 0..25
            8'h1C: code_num_d=8'd0;  8'h32: code_num_d=8'd1;  8'h21: code_num_d=8'd2;
            8'h23: code_num_d=8'd3;  8'h24: code_num_d=8'd4;  8'h2B: code_num_d=8'd5;
            8'h34: code_num_d=8'd6;  8'h33: code_num_d=8'd7;  8'h43: code_num_d=8'd8;
            8'h3B: code_num_d=8'd9;  8'h42: code_num_d=8'd10; 8'h4B: code_num_d=8'd11;
            8'h3A: code_num_d=8'd12; 8'h31: code_num_d=8'd13; 8'h44: code_num_d=8'd14;
            8'h4D: code_num_d=8'd15; 8'h15: code_num_d=8'd16; 8'h2D: code_num_d=8'd17;
            8'h1B: code_num_d=8'd18; 8'h2C: code_num_d=8'd19; 8'h3C: code_num_d=8'd20;
            8'h2A: code_num_d=8'd21; 8'h1D: code_num_d=8'd22; 8'h22: code_num_d=8'd23;
            8'h35: code_num_d=8'd24; 8'h1A: code_num_d=8'd25;

            // digits 0..9 → 26..35
            8'h45: code_num_d=8'd26; 8'h16: code_num_d=8'd27; 8'h1E: code_num_d=8'd28;
            8'h26: code_num_d=8'd29; 8'h25: code_num_d=8'd30; 8'h2E: code_num_d=8'd31;
            8'h36: code_num_d=8'd32; 8'h3D: code_num_d=8'd33; 8'h3E: code_num_d=8'd34;
            8'h46: code_num_d=8'd35;

            // space
            8'h29: code_num_d=8'd36;

            // punctuation → 37..47
            8'h0E: code_num_d=8'd37; 8'h4E: code_num_d=8'd38; 8'h55: code_num_d=8'd39;
            8'h54: code_num_d=8'd40; 8'h5B: code_num_d=8'd41; 8'h5D: code_num_d=8'd42;
            8'h4C: code_num_d=8'd43; 8'h52: code_num_d=8'd44; 8'h41: code_num_d=8'd45;
            8'h49: code_num_d=8'd46; 8'h4A: code_num_d=8'd47;

            // actions
            8'h66: code_num_d=8'd48; // backspace
            8'h5A: code_num_d=8'd49; // enter
        endcase
    end

    // =========================================================================
    // Output register: pulse only on valid MAKE byte at S_BASE
    // =========================================================================
    wire make_cycle = (y == S_BASE) && sc_strobe && (~is_F0) && (~is_E0);

    always @(posedge clock) begin
        if (!resetn) begin
            inputChar_rdy <= 1'b0;
            inputChar     <= 8'd0;
        end else begin
            inputChar_rdy <= 1'b0; // default low
            if (make_cycle && (code_num_d != 8'hFF)) begin
                inputChar_rdy <= 1'b1;       // 1-cycle pulse
                inputChar     <= code_num_d; // valid with the pulse
            end
        end
    end

endmodule
