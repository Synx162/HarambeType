// Converts PS/2 keyboard scancodes to character codes (0-49)
// Processes MAKE codes (key press) and tracks which keys are held
// Properly handles BREAK codes (key release) for normal keyboard behavior
// Ignores extended scancodes (start with E0)

module scancode_to_fontIndex_new(clock, resetn, sc, sc_rdy, inputChar, inputChar_rdy);
    input  wire       clock;
    input  wire       resetn;        // active-low reset
    input  wire [7:0] sc;            // PS/2 scancode byte from PS/2 controller
    input  wire       sc_rdy;        // pulse when sc is valid (from PS/2 controller)
    output reg  [7:0] inputChar;     // output character code (0-49)
    output reg        inputChar_rdy; // pulse when inputChar is valid

    // Check if incoming scancode is a special prefix
    wire is_F0;  // F0 = BREAK code prefix (key release)
    wire is_E0;  // E0 = Extended scancode prefix
    assign is_F0 = (sc == 8'hF0);
    assign is_E0 = (sc == 8'hE0);

    // FSM states to handle scancodes properly
    parameter BASE    = 2'd0;  // Normal state: waiting for a key
    parameter [1:0] GOTF0   = 2'd1;  // Just received F0, next byte is break code
    parameter [1:0] GOTE0   = 2'd2;  // Just received E0, next is extended code
    parameter [1:0] GOTE0F0 = 2'd3;  // Received E0 then F0, next is extended break
    
    reg [1:0] y;  // Current state
    reg [1:0] Y;  // Next state

    // Key tracking registers - tracks which keys are currently pressed
    reg [7:0] key0, key1, key2, key3;  // Up to 4 simultaneous keys
    reg [2:0] num_keys_pressed;        // Number of keys currently held down

    // Next-state logic
    always @(*) begin
        Y = y;  // Default: stay in current state
        
        if (sc_rdy) begin
            case (y)
                BASE: begin
                    if (is_F0) begin
                        Y = GOTF0;  // Next byte will be a break code
                    end else if (is_E0) begin
                        Y = GOTE0;  // Next byte will be extended code
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

    // Decode scancode to character code
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

    // Check if the decoded character is already in the pressed keys list
    wire key_is_pressed;
    assign key_is_pressed = (num_keys_pressed > 0 && key0 == code) ||
                            (num_keys_pressed > 1 && key1 == code) ||
                            (num_keys_pressed > 2 && key2 == code) ||
                            (num_keys_pressed > 3 && key3 == code);

    // Valid MAKE code condition
    wire make_cycle;
    assign make_cycle = (y == BASE) && sc_rdy && ~is_F0 && ~is_E0;

    // Valid BREAK code condition (when we're consuming the break scancode)
    wire break_cycle;
    assign break_cycle = (y == GOTF0) && sc_rdy;

    // Output and key tracking logic
    always @(posedge clock) begin
        if (!resetn) begin
            inputChar_rdy <= 1'b0;
            inputChar     <= 8'd0;
            num_keys_pressed <= 3'd0;
            key0 <= 8'hFF;
            key1 <= 8'hFF;
            key2 <= 8'hFF;
            key3 <= 8'hFF;
        end else begin
            inputChar_rdy <= 1'b0;  // Default: no output
            
            // Handle MAKE codes (key press)
            if (make_cycle && (code != 8'hFF)) begin
                // Always output the character (enables key repeat)
                inputChar_rdy <= 1'b1;
                inputChar     <= code;
                
                // If it's a NEW key (not already pressed), add it to the list
                if (!key_is_pressed) begin
                    case (num_keys_pressed)
                        3'd0: begin
                            key0 <= code;
                            num_keys_pressed <= 3'd1;
                        end
                        3'd1: begin
                            key1 <= code;
                            num_keys_pressed <= 3'd2;
                        end
                        3'd2: begin
                            key2 <= code;
                            num_keys_pressed <= 3'd3;
                        end
                        3'd3: begin
                            key3 <= code;
                            num_keys_pressed <= 3'd4;
                        end
                        default: begin
                            // Already tracking 4 keys, ignore new ones
                        end
                    endcase
                end
            end
            
            // Handle BREAK codes (key release)
            if (break_cycle && (code != 8'hFF)) begin
                // Find and remove the key from the pressed list
                if (num_keys_pressed > 0 && key0 == code) begin
                    // Remove from position 0, shift others up
                    key0 <= key1;
                    key1 <= key2;
                    key2 <= key3;
                    key3 <= 8'hFF;
                    num_keys_pressed <= num_keys_pressed - 1;
                end
                else if (num_keys_pressed > 1 && key1 == code) begin
                    // Remove from position 1, shift others up
                    key1 <= key2;
                    key2 <= key3;
                    key3 <= 8'hFF;
                    num_keys_pressed <= num_keys_pressed - 1;
                end
                else if (num_keys_pressed > 2 && key2 == code) begin
                    // Remove from position 2, shift others up
                    key2 <= key3;
                    key3 <= 8'hFF;
                    num_keys_pressed <= num_keys_pressed - 1;
                end
                else if (num_keys_pressed > 3 && key3 == code) begin
                    // Remove from position 3
                    key3 <= 8'hFF;
                    num_keys_pressed <= num_keys_pressed - 1;
                end
            end
        end
    end

endmodule