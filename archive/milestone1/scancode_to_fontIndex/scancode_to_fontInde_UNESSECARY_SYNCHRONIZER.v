// Converts PS/2 keyboard scancodes to character codes (0-49)
// Only processes MAKE codes (key press), ignores BREAK codes (key release)
// Ignores extended scancodes (prefixed with E0)

module scancode_to_fontIndex (clock,resetn,sc,sc_rdy,inputChar,inputChar_rdy);

    input  wire       clock,
    input  wire       resetn,        // active-low reset
    input  wire [7:0] sc,            // PS/2 scancode byte from PS/2 controller
    input  wire       sc_rdy,        // pulse when sc is valid (from PS/2 controller)
    output reg  [7:0] inputChar,     // output character code (0-49)
    output reg        inputChar_rdy  // pulse when inputChar is valid

    // Synchronize sc_rdy to our clock domain
    reg rdy_meta;     // First synchronization flip-flop
    reg rdy_sync;     // Second synchronization flip-flop (now safe to use)
    reg rdy_sync_d;   // Delayed version for edge detection
    
    always @(posedge clock) begin
        if (!resetn) begin
            rdy_meta   <= 1'b0;
            rdy_sync   <= 1'b0;
            rdy_sync_d <= 1'b0;
        end else begin
            rdy_meta   <= sc_rdy;    // Stage 1: capture the async signal
            rdy_sync   <= rdy_meta;  // Stage 2: now synchronized to our clock
            rdy_sync_d <= rdy_sync;  // Delayed by 1 cycle for edge detection
        end
    end

    wire sc_strobe = rdy_sync & ~rdy_sync_d; // 1-cycle pulse when new scancode arrives

    // Check if incoming scancode is a special prefix (checked directly on 'sc' for fast typing)
    wire is_F0 = (sc == 8'hF0);  // F0 = BREAK code prefix (key release)
    wire is_E0 = (sc == 8'hE0);  // E0 = Extended scancode prefix

    // FSM states to filter out unwanted scancodes
    parameter BASE    = 2'd0,  // Normal state: waiting for a key
                     GOTF0   = 2'd1,  // Just received F0, next byte is break code
                     GOTE0   = 2'd2,  // Just received E0, next is extended code
                     GOTE0F0 = 2'd3;  // Received E0 then F0, next is extended break
    
    reg [1:0] y;  // Current state
    reg [1:0] Y;  // Next state

    // Next-state logic
    always @(*) begin
        Y = y;  // Default: stay in current state
        
        if (sc_strobe) begin
            case (y)
                BASE: begin
                    if (is_F0) begin
                        Y = GOTF0;  // Next byte will be a break code, ignore it
                    end else if (is_E0) begin
                        Y = GOTE0;  // Next byte will be extended, ignore it
                    end else begin
                        Y = BASE;   // Normal make code, stay in base state
                    end
                end
                
                GOTF0: begin
                    Y = BASE; // Consume break code and return to base
                end
                
                GOTE0: begin
                    if (is_F0) begin
                        Y = GOTE0F0;  // E0 F0 sequence, next is extended break
                    end else begin
                        Y = BASE;     // Just extended key, consume and return
                    end
                end
                
                GOTE0F0: begin
                    Y = BASE; // Consume extended break code and return to base
                end
            endcase
        end
    end

    // State register
    always @(posedge clock) begin
        if (!resetn) begin
            y <= BASE;  // Start in base state
        end else begin
            y <= Y;     // Move to next state
        end
    end

    // Decode scancode to character code (uses 'sc' directly for instant response)
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
        endcase
    end

    // Check if the incoming scancode (not latched) is F0 or E0
    wire is_F0_current = (sc == 8'hF0);
    wire is_E0_current = (sc == 8'hE0);
    
    // Valid MAKE code condition
    wire make_cycle = (y == BASE) && sc_strobe && ~is_F0_current && ~is_E0_current;

    // Output register
    always @(posedge clock) begin
        if (!resetn) begin
            inputChar_rdy <= 1'b0;
            inputChar     <= 8'd0;
        end else begin
            if (make_cycle && (code != 8'hFF)) begin
                inputChar_rdy <= 1'b1;      // Pulse high for 1 cycle
                inputChar     <= code;      // Output the character code
            end else begin
                inputChar_rdy <= 1'b0;      // Otherwise keep ready signal low
            end
        end
    end

endmodule

// =============================================================================
// DETAILED EXPLANATION SECTIONS
// =============================================================================

// SYNCHRONIZATION:
// ---------------
// The sc_rdy signal comes from the PS/2 controller which runs on the same clock
// (CLOCK_50) but ps2_rec is combinational logic that can have glitches. We use
// a two-flip-flop synchronizer to capture a clean, stable signal.
//
// First FF (rdy_meta): Captures the incoming signal, might have glitches
// Second FF (rdy_sync): Re-samples after 1 cycle, now stable and safe to use
// Third FF (rdy_sync_d): Delayed version for edge detection
//
// Edge Detection: sc_strobe = rdy_sync & ~rdy_sync_d creates a 1-cycle pulse
// whenever sc_rdy rises, indicating a new scancode byte has arrived.

// STATE MACHINE:
// -------------
// PS/2 keyboard sends different types of scancodes:
// - MAKE code: Single byte when key pressed (e.g., 0x1C for 'A')
// - BREAK code: F0 followed by key code when released (e.g., F0 1C)
// - Extended codes: E0 followed by key code (e.g., E0 75 for up arrow)
// - Extended break: E0 F0 followed by key code
//
// We only want simple MAKE codes, so the FSM filters out everything else:
// - BASE state: Normal operation, waiting for keys
// - GOTF0 state: Just saw F0, next byte is a break code (ignore it)
// - GOTE0 state: Just saw E0, next is an extended code (ignore it)  
// - GOTE0F0 state: Saw E0 then F0, next is extended break (ignore it)

// FAST TYPING FIX:
// ---------------
// The decoder and FSM check 'sc' directly (not a latched version) so that
// state transitions and character decoding happen in the same cycle the data
// arrives. This prevents the FSM from getting out of sync when bytes arrive
// back-to-back during fast typing.

// CHARACTER MAPPING:
// -----------------
// Mapping:
//   0-25  : letters a-z
//   26    : space
//   27-36 : digits 0-9
//   37-47 : punctuation (` - = [ ] \ ; ' , . /)
//   48    : backspace
//   49    : enter
//   FF    : invalid/unmapped key