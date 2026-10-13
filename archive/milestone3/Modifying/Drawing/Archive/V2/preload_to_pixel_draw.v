module preload_to_pixel_draw(char_index, char_valid, clock, resetn, cursor_col, cursor_row, busy, done, font_address, font_color9, x, y, color, write);
	// INPUTS THAT ARE RECEIVED
	input [4:0] char_index;  // (0-26) representing (a-z)
	input char_valid;    // pulse that tells us when a char was received and we can start drawing
	input clock, resetn;
	input [9:0]cursor_col, cursor_row;   // where to place it in text grid, 10 bit cause 640&480 both < 1024
	
	// INPUTS THAT WE CONTROL
	parameter integer H_MARGIN = 50;     // keep the same horizontal alignment as the text box 
	parameter integer V_MARGIN = 125;   	// defines how far from top and left margin our text box starts
	parameter integer CHAR_H = 8;
	parameter integer CHAR_W = 8;       // size of the glyph to be printed
	parameter integer IMAGE_W = 216;              // width of the glyph file
	parameter integer SCALE = 2;                // how much we want to magnify the glyphs
	
	parameter [8:0] BACKGROUND_COLOR = 9'b000000000;    // background color of the MIF 9-bit
	parameter [4:0] LETTER_SPACE = 5'd26; // match target_words space index

	// OUTPUTS
	output reg busy;          // 1 while still drawing
	output reg done;          // pulse for one clock cycle when done 
	
	// MEMORY STUFF
	output reg [10:0]font_address;       // enough to get to 8x8x27 = 1728 (2^11 = 2048)
	input [8:0] font_color9;          	// color depth of MIF File 
	
	// OUTPUTS TO ADAPTER
	output reg[9:0] x;        
	output reg[8:0] y;
	output reg[8:0] color;    // color to be written on screen
	output reg write;         // pulse for when to write to screen
	
	// FSM STATE CODES
	
	parameter IDLE = 3'd0, SETUP = 3'd1, READ = 3'd2, DRAW = 3'd3, NEXT_PX = 3'd4, NEXT_ROW = 3'd5,
		      DONE = 3'd6;
			  
	reg [2:0] Y; // state FFs
	
	// registers
	
	reg [9:0]  base_x, base_y; // Our actual cursor inside the textbox
	reg [9:0]  fx, fy; // inside MIF file coordinates // 10-bits for calc. simplicity (only really 3-bits)	 	
	reg [1:0]  sx, sy; // scale sub-pixels (up to 4x scaling factor)
	// reg [19:0] base_address, row_base_address; // math for calculating staring address and row respectively, // UNUSED base_address
	reg [19:0] row_base_address; // math for calculating row address for the letter we want to draw
	reg [8:0]  px_color; // stores the color depth   
	
	//Support variables
	
	wire [9:0] DRAW_W = CHAR_W * SCALE; // Actual letter width that is being drawn onto the screen w/scaling
	wire [9:0] DRAW_H = CHAR_H * SCALE; // ^^ same but for height
	wire [9:0] chars_per_row = IMAGE_W / CHAR_W; // # of chars that fit in each MIF row (always 27 letters/chars in row)
	wire [9:0] letter_row = char_index / chars_per_row; // the row of letters in which the char we will print is on
	wire [9:0] letter_col = char_index % chars_per_row; // the col of letters in which the char we will print is on
	
	
	// FSM 
	
	always @(posedge clock, negedge resetn) begin
		if(!resetn) begin
			Y <= IDLE;
			busy <= 1'b0;
			done <= 1'b0;
			write <= 1'b0;
			x <= 10'd0;
			y <= 9'd0;
			color <= 9'd0;
			base_x <= 10'd0;
			base_y <= 10'd0;
			fx <= 10'd0;
			fy <= 10'd0;
			sx <= 2'd0;
			sy <= 2'd0;
			// base_address <= 20'd0; // UNUSED
			row_base_address <= 20'd0;
			font_address <= 11'd0;
			px_color <= 9'd0;
			end
		else begin
		
		// default values to prevent random vals
		write <= 1'b0;
		done <= 1'b0;
		
		case(Y)
			IDLE: begin
				write <= 1'b0;
				busy <= 1'b0;
				if(char_valid) begin // handle space characters specially
					if (char_index == LETTER_SPACE) begin // skip drawing for space
						done <= 1'b1; // immediately signal "done" for space so upstream can advance cursor
						// stay in IDLE; no drawing, no busy
					end else begin // normal (non-space) character path
						busy <= 1'b1;
						// where to start drawing on the display
						base_x <= H_MARGIN + cursor_col * DRAW_W; // textbox + current pos. textbox
						base_y <= V_MARGIN + cursor_row * DRAW_H;
			
						// initialize loop variables
						fx <= 0; fy <= 0; sx <= 0; sy <= 0;
						
						//compute the letter's top-left coordinate in the MIFFY file
						// base_address <= (letter_row * CHAR_H * IMAGE_W) + (letter_col * CHAR_W); // UNUSED reference starting address
						row_base_address <= (letter_row * CHAR_H * IMAGE_W) + (letter_col * CHAR_W); // relative address
						
						Y <= SETUP;
					end
				end
			end
			
		// -------------------------
			SETUP: begin
				write <= 1'b0;
				font_address <= row_base_address + fx;
				Y <= READ; 
				end
			
		// ---------
		
			READ: begin
				write <= 1'b0;
				// remember what color to sen
				px_color <= font_color9;
				
				sx <= 0;
				sy <= 0; 
				Y <= DRAW;
			end
			
			//-------------
			DRAW: begin // RE-READ
				if(px_color != BACKGROUND_COLOR) begin
					// scaling factor here 
					
					x <= base_x + (fx * SCALE) + sx;
					y <= base_y + (fy * SCALE) + sy;
					color <= px_color; // print color to screen
					write <= 1'b1;
				end
				
				// increment scaling loop
				if(sx == (SCALE-1)) begin 
					sx <= 0;
					if(sy == (SCALE-1))begin 
						sy <= 0;
						Y <= NEXT_PX;
					
					end else begin
						sy <= sy + 1;
						end
				end else begin 
					sx <= sx + 1;
                end
			end
			
		// ----------------------------
			NEXT_PX: begin
			write <= 1'b0;
			//get next pixel in this row_base_address
			if(fx == (CHAR_W - 1)) begin
				fx <= 0; 
				 Y <= NEXT_ROW;
			end else begin
				fx <= fx + 1; // possible none sense incrementing fx twice
				font_address <= row_base_address + (fx + 1); // FLAG FLAH 
				Y <= READ;
				end
			end
			
			// --------------------
			
			NEXT_ROW: begin 
			write <= 1'b0;
				if (fy == (CHAR_H - 1)) begin 
					Y <= DONE; // set to done, since
				end else begin
					fy <= fy + 1;
					row_base_address <= row_base_address + IMAGE_W; // to move down one row, means moving down by IMG_W addresses
					font_address <= row_base_address + IMAGE_W; // to fetch the first pixel of this new Row
					Y <= READ;
				end
			end
			
			DONE: begin
				write <= 1'b0;
				busy <= 1'b0;
				done <= 1'b1;
				Y <= IDLE;
			end
		endcase
	end 
end
	
endmodule
