module num_to_pixel_draw(
    digit0, digit1, digit2, digit3, num_digits, num_valid,
    clock, resetn, cursor_col, cursor_row,
    busy, done, num_address, num_color9,
    x, y, color, write
);
    // INPUTS THAT ARE RECEIVED
    input [3:0]digit0;  // least-significant (rightmost) digit
    input [3:0]digit1;
    input [3:0]digit2;
    input [3:0]digit3;  // most-significant (leftmost) digit
    input [2:0]num_digits;  // how many digits to draw (we will use 2 for now tens, ones)
    input num_valid;   // pulse to start drawing both digits
    input clock, resetn;
    input [9:0] cursor_col, cursor_row;   // where to place the *leftmost* digit in text grid
    
    // INPUTS THAT WE CONTROL
    parameter integer H_MARGIN  = 545; 
    parameter integer V_MARGIN  = 25;
    parameter integer CHAR_H    = 8;
    parameter integer CHAR_W    = 8;
    parameter integer IMAGE_W   = 80;
    parameter integer SCALE     = 3;
    
    // CHANGED: 3-bit background color
    parameter [2:0]BACKGROUND_COLOR = 3'b000;
    
    // CONNECTION TO DIGIT FONT ROM
    output reg [9:0] num_address;
    input      [2:0] num_color9;      // CHANGED: 3-bit
    
    // VGA OUTPUTS
    output reg [9:0]x, y;
    output reg [2:0]color;            // CHANGED: 3-bit
    output reg write;
    output reg busy;
    output reg done;
    
    // DERIVED CONSTANTS
    wire [9:0]DRAW_W = CHAR_W * SCALE;
    wire [9:0]DRAW_H = CHAR_H * SCALE;
    
    // FSM STATES
    parameter IDLE = 3'd0, SETUP = 3'd1, READ = 3'd2, DRAW = 3'd3, NEXT_PX = 3'd4, NEXT_ROW = 3'd5, DONE = 3'd6, NEXT_DIGIT = 3'd7;
    reg [2:0] Y;  // NEXT STATE 
    
    // REGISTERS
    reg [9:0]base_x, base_y;
    reg [9:0]fx, fy;
    reg [1:0]sx, sy;
    reg [19:0]base_address;
    reg [19:0]row_base_address;
    reg [2:0]px_color;                // CHANGED: 3-bit
    
    reg [2:0]digit_index;   // 0 = tens (digit1), 1 = ones (digit0)
    reg [3:0]current_digit; // 0..9
    
    // select which digit value to draw based on digit_index
    always @(*) begin
        case (digit_index)
            3'd0: current_digit = digit1; // tens, left digit
            3'd1: current_digit = digit0; // ones, right digit
            default: current_digit = 4'd0;
        endcase
    end
    
    // FSM
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            Y <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            write <= 1'b0;
            
            x <= 10'd0;
            y <= 10'd0;
            color <= 3'd0;           // CHANGED: 3-bit reset
            
            base_x <= 10'd0;
            base_y <= 10'd0;
            
            fx <= 10'd0;
            fy <= 10'd0;
            sx <= 2'd0;
            sy <= 2'd0;
            
            base_address <= 20'd0;
            row_base_address <= 20'd0;
            px_color <= 3'd0;        // CHANGED: 3-bit reset
            
            num_address <= 10'd0;
            digit_index <= 3'd0;
        end else begin
            write <= 1'b0;
            done  <= 1'b0;
            
            case (Y)
                IDLE: begin
                    busy  <= 1'b0;
                    if (num_valid && (num_digits != 3'd0)) begin
                        busy <= 1'b1;
                        digit_index <= 3'd0;  // start with tens digit on the left
                        fx <= 10'd0;
                        fy <= 10'd0;
                        sx <= 2'd0;
                        sy <= 2'd0;
                        Y  <= SETUP;
                    end
                end
                
                SETUP: begin
                    // position this digit on screen
                    base_x <= H_MARGIN + (cursor_col + digit_index) * DRAW_W;
                    base_y <= V_MARGIN + cursor_row * DRAW_H;
                    
                    // compute first address in MIF for this digit
                    base_address     <= current_digit * CHAR_W;
                    row_base_address <= current_digit * CHAR_W;
                    num_address      <= current_digit * CHAR_W;
                    
                    Y <= READ;
                end
                
                READ: begin
                    px_color <= num_color9;    // CHANGED: 3-bit sample
                    Y <= DRAW;
                end
                
                DRAW: begin
                    if (px_color != BACKGROUND_COLOR) begin
                        x <= base_x + (fx * SCALE) + sx;
                        y <= base_y + (fy * SCALE) + sy;

                        // CHANGED: 3-bit colors (R,G,B) for red / yellow / green
                        if ((digit1 == 4'd0) && (digit0 <= 4'd3)) begin
                            color <= 3'b100;   // red-ish (low time)
                        end else if ((digit1 == 4'd0) && (digit0 >= 4'd4) && (digit0 <= 4'd7)) begin
                            color <= 3'b110;   // yellow-ish (mid time)
                        end else begin
                            color <= 3'b010;   // green-ish (safe)
                        end
                        
                        write <= 1'b1;   // display on screen 
                    end
                    
                    // scaling loop (x3 for now)
                    if (sx == (SCALE - 1)) begin
                        sx <= 2'd0;
                        if (sy == (SCALE - 1)) begin
                            sy <= 2'd0;
                            Y  <= NEXT_PX;
                        end else begin
                            sy <= sy + 2'd1;
                        end
                    end else begin
                        sx <= sx + 2'd1;
                    end
                end
                
                NEXT_PX: begin
                    if (fx == (CHAR_W - 1)) begin   // done w/ columns?
                        fx <= 10'd0;
                        Y  <= NEXT_ROW;
                    end else begin
                        fx <= fx + 10'd1;
                        num_address <= row_base_address + fx + 10'd1;
                        Y <= READ;
                    end
                end
                
                NEXT_ROW: begin
                    if (fy == (CHAR_H - 1)) begin    // done w/ all rows?
                        if (digit_index == 3'd1) begin   // done both digits ?
                            Y <= DONE;
                        end else begin   // move to next digit (ones)
                            digit_index <= digit_index + 3'd1; // 0 -> 1
                            fx <= 10'd0;
                            fy <= 10'd0;
                            sx <= 2'd0;
                            sy <= 2'd0;
                            Y  <= NEXT_DIGIT;
                        end
                    end else begin     // next row of same digit
                        fy <= fy + 10'd1;
                        row_base_address <= row_base_address + IMAGE_W;
                        num_address      <= row_base_address + IMAGE_W;
                        Y <= READ;
                    end
                end
                
                NEXT_DIGIT: begin    // move the next digit to the right of the one that was just drawn
                    base_x <= H_MARGIN + (cursor_col + digit_index) * DRAW_W;
                    base_y <= V_MARGIN + cursor_row * DRAW_H;
                    
                    base_address     <= current_digit * CHAR_W;
                    row_base_address <= current_digit * CHAR_W;
                    num_address      <= current_digit * CHAR_W;
                    
                    Y <= READ;
                end
                
                DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    digit_index <= 3'd0;
                    Y <= IDLE;
                end
            endcase
        end
    end

endmodule
