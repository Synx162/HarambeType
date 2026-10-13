module target_words (clock, resetn, enable_send, char_sent, letter_ready);

	input clock, resetn;

	parameter integer n_letters = 8;    // num of letters incl. terminator
	parameter integer n_words   = 40;   // num of words
	parameter [4:0] LETTER_SPACE = 5'd26;

	reg [4:0] words [(n_words)-1:0][(n_letters)-1:0];

	integer i, j;

	input wire enable_send;       // limited by either the number of words 
	output reg[4:0] char_sent;    // number we are sending out

	initial begin
		// default: everything = space (acts as terminator)
		for (i = 0; i < n_words; i = i + 1) begin
			for (j = 0; j < n_letters; j = j + 1) begin
				words[i][j] = LETTER_SPACE;
			end
		end

		// word 0: crash
		words[0][0] = 5'd2;  // c
		words[0][1] = 5'd17; // r
		words[0][2] = 5'd0;  // a
		words[0][3] = 5'd18; // s
		words[0][4] = 5'd7;  // h

		// word 1: aware
		words[1][0] = 5'd0;  // a
		words[1][1] = 5'd22; // w
		words[1][2] = 5'd0;  // a
		words[1][3] = 5'd17; // r
		words[1][4] = 5'd4;  // e

		// word 2: dish
		words[2][0] = 5'd3;  // d
		words[2][1] = 5'd8;  // i
		words[2][2] = 5'd18; // s
		words[2][3] = 5'd7;  // h

		// word 3: sink
		words[3][0] = 5'd18; // s
		words[3][1] = 5'd8;  // i
		words[3][2] = 5'd13; // n
		words[3][3] = 5'd10; // k

		// word 4: studio
		words[4][0] = 5'd18; // s
		words[4][1] = 5'd19; // t
		words[4][2] = 5'd20; // u
		words[4][3] = 5'd3;  // d
		words[4][4] = 5'd8;  // i
		words[4][5] = 5'd14; // o

		// word 5: ritual
		words[5][0] = 5'd17; // r
		words[5][1] = 5'd8;  // i
		words[5][2] = 5'd19; // t
		words[5][3] = 5'd20; // u
		words[5][4] = 5'd0;  // a
		words[5][5] = 5'd11; // l

		// word 6: week
		words[6][0] = 5'd22; // w
		words[6][1] = 5'd4;  // e
		words[6][2] = 5'd4;  // e
		words[6][3] = 5'd10; // k

		// word 7: name
		words[7][0] = 5'd13; // n
		words[7][1] = 5'd0;  // a
		words[7][2] = 5'd12; // m
		words[7][3] = 5'd4;  // e

		// word 8: lecture
		words[8][0] = 5'd11; // l
		words[8][1] = 5'd4;  // e
		words[8][2] = 5'd2;  // c
		words[8][3] = 5'd19; // t
		words[8][4] = 5'd20; // u
		words[8][5] = 5'd17; // r
		words[8][6] = 5'd4;  // e

		// word 9: hear
		words[9][0] = 5'd7;  // h
		words[9][1] = 5'd4;  // e
		words[9][2] = 5'd0;  // a
		words[9][3] = 5'd17; // r

		// word 10: sweater
		words[10][0] = 5'd18; // s
		words[10][1] = 5'd22; // w
		words[10][2] = 5'd4;  // e
		words[10][3] = 5'd0;  // a
		words[10][4] = 5'd19; // t
		words[10][5] = 5'd4;  // e
		words[10][6] = 5'd17; // r

		// word 11: glow
		words[11][0] = 5'd6;  // g
		words[11][1] = 5'd11; // l
		words[11][2] = 5'd14; // o
		words[11][3] = 5'd22; // w

		// word 12: trustee
		words[12][0] = 5'd19; // t
		words[12][1] = 5'd17; // r
		words[12][2] = 5'd20; // u
		words[12][3] = 5'd18; // s
		words[12][4] = 5'd19; // t
		words[12][5] = 5'd4;  // e
		words[12][6] = 5'd4;  // e

		// word 13: safety
		words[13][0] = 5'd18; // s
		words[13][1] = 5'd0;  // a
		words[13][2] = 5'd5;  // f
		words[13][3] = 5'd4;  // e
		words[13][4] = 5'd19; // t
		words[13][5] = 5'd24; // y

		// word 14: defend
		words[14][0] = 5'd3;  // d
		words[14][1] = 5'd4;  // e
		words[14][2] = 5'd5;  // f
		words[14][3] = 5'd4;  // e
		words[14][4] = 5'd13; // n
		words[14][5] = 5'd3;  // d

		// word 15: social
		words[15][0] = 5'd18; // s
		words[15][1] = 5'd14; // o
		words[15][2] = 5'd2;  // c
		words[15][3] = 5'd8;  // i
		words[15][4] = 5'd0;  // a
		words[15][5] = 5'd11; // l

		// word 16: peasant
		words[16][0] = 5'd15; // p
		words[16][1] = 5'd4;  // e
		words[16][2] = 5'd0;  // a
		words[16][3] = 5'd18; // s
		words[16][4] = 5'd0;  // a
		words[16][5] = 5'd13; // n
		words[16][6] = 5'd19; // t

		// word 17: export
		words[17][0] = 5'd4;  // e
		words[17][1] = 5'd23; // x
		words[17][2] = 5'd15; // p
		words[17][3] = 5'd14; // o
		words[17][4] = 5'd17; // r
		words[17][5] = 5'd19; // t

		// word 18: episode
		words[18][0] = 5'd4;  // e
		words[18][1] = 5'd15; // p
		words[18][2] = 5'd8;  // i
		words[18][3] = 5'd18; // s
		words[18][4] = 5'd14; // o
		words[18][5] = 5'd3;  // d
		words[18][6] = 5'd4;  // e

		// word 19: dome
		words[19][0] = 5'd3;  // d
		words[19][1] = 5'd14; // o
		words[19][2] = 5'd12; // m
		words[19][3] = 5'd4;  // e

		// word 20: shelf
		words[20][0] = 5'd18; // s
		words[20][1] = 5'd7;  // h
		words[20][2] = 5'd4;  // e
		words[20][3] = 5'd11; // l
		words[20][4] = 5'd5;  // f

		// word 21: delete
		words[21][0] = 5'd3;  // d
		words[21][1] = 5'd4;  // e
		words[21][2] = 5'd11; // l
		words[21][3] = 5'd4;  // e
		words[21][4] = 5'd19; // t
		words[21][5] = 5'd4;  // e

		// word 22: survey
		words[22][0] = 5'd18; // s
		words[22][1] = 5'd20; // u
		words[22][2] = 5'd17; // r
		words[22][3] = 5'd21; // v
		words[22][4] = 5'd4;  // e
		words[22][5] = 5'd24; // y

		// word 23: delay
		words[23][0] = 5'd3;  // d
		words[23][1] = 5'd4;  // e
		words[23][2] = 5'd11; // l
		words[23][3] = 5'd0;  // a
		words[23][4] = 5'd24; // y

		// word 24: march
		words[24][0] = 5'd12; // m
		words[24][1] = 5'd0;  // a
		words[24][2] = 5'd17; // r
		words[24][3] = 5'd2;  // c
		words[24][4] = 5'd7;  // h

		// word 25: excuse
		words[25][0] = 5'd4;  // e
		words[25][1] = 5'd23; // x
		words[25][2] = 5'd2;  // c
		words[25][3] = 5'd20; // u
		words[25][4] = 5'd18; // s
		words[25][5] = 5'd4;  // e

		// word 26: year
		words[26][0] = 5'd24; // y
		words[26][1] = 5'd4;  // e
		words[26][2] = 5'd0;  // a
		words[26][3] = 5'd17; // r

		// word 27: yearn
		words[27][0] = 5'd24; // y
		words[27][1] = 5'd4;  // e
		words[27][2] = 5'd0;  // a
		words[27][3] = 5'd17; // r
		words[27][4] = 5'd13; // n

		// word 28: breed
		words[28][0] = 5'd1;  // b
		words[28][1] = 5'd17; // r
		words[28][2] = 5'd4;  // e
		words[28][3] = 5'd4;  // e
		words[28][4] = 5'd3;  // d

		// word 29: cheat
		words[29][0] = 5'd2;  // c
		words[29][1] = 5'd7;  // h
		words[29][2] = 5'd4;  // e
		words[29][3] = 5'd0;  // a
		words[29][4] = 5'd19; // t

		// word 30: confuse
		words[30][0] = 5'd2;  // c
		words[30][1] = 5'd14; // o
		words[30][2] = 5'd13; // n
		words[30][3] = 5'd5;  // f
		words[30][4] = 5'd20; // u
		words[30][5] = 5'd18; // s
		words[30][6] = 5'd4;  // e

		// word 31: law
		words[31][0] = 5'd11; // l
		words[31][1] = 5'd0;  // a
		words[31][2] = 5'd22; // w

		// word 32: alarm
		words[32][0] = 5'd0;  // a
		words[32][1] = 5'd11; // l
		words[32][2] = 5'd0;  // a
		words[32][3] = 5'd17; // r
		words[32][4] = 5'd12; // m

		// word 33: tourist
		words[33][0] = 5'd19; // t
		words[33][1] = 5'd14; // o
		words[33][2] = 5'd20; // u
		words[33][3] = 5'd17; // r
		words[33][4] = 5'd8;  // i
		words[33][5] = 5'd18; // s
		words[33][6] = 5'd19; // t

		// word 34: grief
		words[34][0] = 5'd6;  // g
		words[34][1] = 5'd17; // r
		words[34][2] = 5'd8;  // i
		words[34][3] = 5'd4;  // e
		words[34][4] = 5'd5;  // f

		// word 35: crowd
		words[35][0] = 5'd2;  // c
		words[35][1] = 5'd17; // r
		words[35][2] = 5'd14; // o
		words[35][3] = 5'd22; // w
		words[35][4] = 5'd3;  // d

		// word 36: basket
		words[36][0] = 5'd1;  // b
		words[36][1] = 5'd0;  // a
		words[36][2] = 5'd18; // s
		words[36][3] = 5'd10; // k
		words[36][4] = 5'd4;  // e
		words[36][5] = 5'd19; // t

		// word 37: proper
		words[37][0] = 5'd15; // p
		words[37][1] = 5'd17; // r
		words[37][2] = 5'd14; // o
		words[37][3] = 5'd15; // p
		words[37][4] = 5'd4;  // e
		words[37][5] = 5'd17; // r

		// word 38: rear
		words[38][0] = 5'd17; // r
		words[38][1] = 5'd4;  // e
		words[38][2] = 5'd0;  // a
		words[38][3] = 5'd17; // r

		// word 39: salmon
		words[39][0] = 5'd18; // s
		words[39][1] = 5'd0;  // a
		words[39][2] = 5'd11; // l
		words[39][3] = 5'd12; // m
		words[39][4] = 5'd14; // o
		words[39][5] = 5'd13; // n
	end

	 // indices and flag
    reg [5:0] word_number;     // 0..39  (needs 6 bits)
    reg [2:0] letter_number;   // 0..7   (needs 3 bits)
    reg sending_space;
	output reg letter_ready;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            word_number <= 0;
            letter_number <= 0;
            sending_space <= 0;
            char_sent <= LETTER_SPACE;
			letter_ready <= 1'b0;
        end else begin
			letter_ready <= 1'b0;
		
			if (enable_send) begin
			
				if (sending_space) begin
					// send exactly one space between words
					char_sent <= LETTER_SPACE;
					sending_space <= 0;
					letter_ready <= 1'b1;

					// go to next word
					if (word_number == n_words-1)
						word_number <= 0;
					else
						word_number <= word_number + 1;
				end else begin
					// reached space inside table
					if (words[word_number][letter_number] == LETTER_SPACE) begin
						// DO NOT send this space from table
						sending_space <= 1;   // next cycle we send one space
						letter_number <= 0;   // reset for the next word
						letter_ready <= 1'b0;
					end
					else begin
						// normal letter: send it
						char_sent <= words[word_number][letter_number];
						letter_number <= letter_number + 1;
						letter_ready <= 1'b1;
					end
				end

			end
		end
        // if !enable_send hold
    end
endmodule