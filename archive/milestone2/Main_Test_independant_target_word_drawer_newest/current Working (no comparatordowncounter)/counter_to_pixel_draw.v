module num_to_pixel_draw(digit0, digit1, digit2, digit3, num_digits, num_valid, clock, resetn, cursor_col, cursor_row, busy, done, num_address, num_color9, x, y, color, write);
	// INPUTS THAT ARE RECEIVED
	input [3:0]digit0;  // least-significant (rightmost) digit
	input [3:0]digit1;
	input [3:0]digit2;
	input [3:0]digit3;  // most-significant (leftmost) digit
	input [2:0]num_digits;  // how many digits to draw: 1..4 (starting from digit3 on the left)
	input num_valid;   // pulse to start drawing all digits
	input clock, resetn;
	input [9:0] cursor_col, cursor_row;   // where to place the *leftmost* digit in text grid
	
	// INPUTS THAT WE CONTROL
	parameter integer H_MARGIN  = 545; 
	parameter integer V_MARGIN  = 30;   // defines how far from top and left margin our text box starts
	parameter integer CHAR_H    = 8;
	parameter integer CHAR_W    = 8;     // size of the glyph to be printed
	parameter integer IMAGE_W   = 80;    // width of the digits MIF (10 digits * 8px)
	parameter integer SCALE     = 2;     // how much we want to magnify the glyphs
	
	parameter [8:0]BACKGROUND_COLOR = 9'b000000000;    // background color of the MIF 9-bit
	
	// CONNECTION TO DIGIT ROM
	output reg [9:0] num_address;    // enough to get 8 x 8 x 10 = 640 (2^10 = 1024)
	input [8:0] num_color9;
	
	// VGA OUTPUTS
	output reg [9:0]x, y;
	output reg [8:0]color;
	output reg write;
	output reg busy;
	output reg done;
	
	// DERIVED CONSTANTS
	wire [9:0]DRAW_W = CHAR_W * SCALE; // Actual digit width on screen (with scaling)
	wire [9:0]DRAW_H = CHAR_H * SCALE; // Actual digit height on screen
	
	// FSM STATE CODES
	parameter IDLE = 3'd0, SETUP = 3'd1, READ = 3'd2, DRAW = 3'd3, NEXT_PX = 3'd4, NEXT_ROW = 3'd5, DONE = 3'd6, NEXT_DIGIT = 3'd7; 
	reg [2:0] Y; // state FFs
	
	// REGISTERS
	reg [9:0]base_x, base_y;   // current digit's upper-left corner on the screen
	reg [9:0]fx, fy;  // inside MIF file coordinates (0..7)	 	
	reg [1:0]sx, sy;  // scale sub-pixels (0..SCALE-1) for up to 4x scaling
	reg [19:0]base_address;    // not strictly needed but kept for similarity
	reg [19:0]row_base_address; // starting address of current row of current digit
	reg [8:0]px_color;  // stores the color depth   
	
	reg [2:0]digit_index;   // which digit we are currently drawing (0..3)
	reg [3:0]current_digit;   // value 0..9 of the current digit
	
	// choose which digit to draw based on digit_index
	// digits are ordered left-to-right as: digit3, digit2, digit1, digit0
	always @(*) begin
		case (digit_index)
			3'd0: current_digit = (num_digits > 3'd0) ? digit3 : 4'd0;
			3'd1: current_digit = (num_digits > 3'd1) ? digit2 : 4'd0;
			3'd2: current_digit = (num_digits > 3'd2) ? digit1 : 4'd0;
			3'd3: current_digit = (num_digits > 3'd3) ? digit0 : 4'd0;
			default: current_digit = 4'd0;
		endcase
	end
	
	// FSM
	always @(posedge clock, negedge resetn) begin
		if (!resetn) begin
			Y <= IDLE;
			busy <= 1'b0;
			done <= 1'b0;
			write <= 1'b0;
			
			x <= 10'd0;
			y <= 10'd0;
			color <= 9'd0;
			
			base_x <= 10'd0;
			base_y <= 10'd0;
			
			fx <= 10'd0;
			fy <= 10'd0;
			sx <= 2'd0;
			sy <= 2'd0;
			
			base_address <= 20'd0;
			row_base_address <= 20'd0;
			px_color <= 9'd0;
			
			num_address <= 10'd0;
			digit_index <= 3'd0;
		end else begin
		
			// default values to prevent random vals
			write <= 1'b0;
			done  <= 1'b0;
			
			case (Y)
				IDLE: begin
					write <= 1'b0;
					busy  <= 1'b0;
					
					if (num_valid && (num_digits != 3'd0)) begin
						busy <= 1'b1;
						
						// start with leftmost digit (digit3)
						digit_index <= 3'd0;
						
						// where to start drawing on the display
						base_x <= H_MARGIN + cursor_col * DRAW_W;
						base_y <= V_MARGIN + cursor_row * DRAW_H;
						
						// initialize loop variables
						fx <= 10'd0; 
						fy <= 10'd0; 
						sx <= 2'd0; 
						sy <= 2'd0;
						
						// compute the digit's top-left coordinate in the MIF file
						// digits 0..9 laid out horizontally: each digit is CHAR_W wide
						base_address      <= current_digit * CHAR_W;
						row_base_address  <= current_digit * CHAR_W;
						
						Y <= SETUP;
					end
				end
				
				SETUP: begin
					write <= 1'b0;
					num_address <= row_base_address + fx;
					Y <= READ;
				end

				READ: begin
					write <= 1'b0;
					px_color <= num_color9;
					Y <= DRAW;
				end

				DRAW: begin
					write <= 1'b0;
					
					if (px_color != BACKGROUND_COLOR) begin
						x <= base_x + (fx * SCALE) + sx;
						y <= base_y + (fy * SCALE) + sy;
						if (digit1 == 1'd0 && digit0 <= 1'd3) begin      // if counter is less/ equal to 3 seconds
							color <= 9'b111000000;                   // should be red according to RGB
						end else begin
							color <= px_color;
						end
						write <= 1'b1;
					end
					
					// increment scaling loop
					if (sx == (SCALE - 1)) begin
						sx <= 0;
						if (sy == (SCALE - 1)) begin
							sy <= 0;
							Y <= NEXT_PX;
						end else begin
							sy <= sy + 1;
						end
					end else begin
						sx <= sx + 1;
					end
				end

				NEXT_PX: begin
					write <= 1'b0;
					
					// get next pixel in this row_base_address
					if (fx == (CHAR_W - 1)) begin
						fx <= 0; 
						Y  <= NEXT_ROW;
					end else begin
						fx <= fx + 1;
						num_address <= row_base_address + fx + 1;
						Y <= READ;
					end
				end

				NEXT_ROW: begin
					write <= 1'b0;
					
					if (fy == (CHAR_H - 1)) begin
						// Finished this digit's 8x8 glyph
						if (digit_index == (num_digits - 1)) begin
							Y <= DONE; // all requested digits done
						end else begin
							// prepare for next digit to the right
							fy <= 10'd0;
							fx <= 10'd0;
							sx <= 2'd0;
							sy <= 2'd0;
							
							digit_index <= digit_index + 1;
							Y <= NEXT_DIGIT;
						end
					end else begin
						// move down one row in the same digit
						fy <= fy + 1;
						row_base_address <= row_base_address + IMAGE_W;     // to move down one row
						num_address      <= row_base_address + IMAGE_W;     // fetch first pixel of new row
						Y <= READ;
					end
				end

				NEXT_DIGIT: begin
					write <= 1'b0;
					
					// new digit's screen position: one DRAW_W to the right per digit_index
					base_x <= H_MARGIN + (cursor_col + digit_index) * DRAW_W;
					base_y <= V_MARGIN + cursor_row * DRAW_H;
					
					// new digit's MIF starting address
					base_address     <= current_digit * CHAR_W;
					row_base_address <= current_digit * CHAR_W;
					
					Y <= SETUP;
				end

				DONE: begin
					write <= 1'b0;
					busy  <= 1'b0;
					done  <= 1'b1;
					digit_index <= 3'd0;
					Y <= IDLE;
				end
			endcase
		end
	end
	
endmodule
