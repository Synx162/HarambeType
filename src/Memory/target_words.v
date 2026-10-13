module target_words (clock, resetn, reshuffle, enable_send, char_sent, letter_ready);

    input clock, resetn;
	input wire reshuffle;   // pulse to generate new random sequence

    parameter integer n_letters = 8;    // num of letters incl. terminator
	parameter integer n_words   = 200;  // 200 words total

    parameter [4:0] LETTER_SPACE = 5'd26;

    // FIXED: Declare as a single 1D array with calculated indices
     reg [4:0] words [0:(n_words * n_letters)-1]; // 200 words × 8 letters = 1600 elements

    integer i, j;

    input  wire       enable_send;    // one-cycle request for next char
    output reg [4:0]  char_sent;      // letter index out
    output reg        letter_ready;   // 1-cycle pulse when char_sent is valid

    // init table
    initial begin
        // default: everything = space - acts as the end of a word
        for (i = 0; i < (n_words * n_letters); i = i + 1) begin
            words[i] = LETTER_SPACE;
        end

        // word 0: crash
        words[0*8 + 0] = 5'd2;  // c
        words[0*8 + 1] = 5'd17; // r
        words[0*8 + 2] = 5'd0;  // a
        words[0*8 + 3] = 5'd18; // s
        words[0*8 + 4] = 5'd7;  // h

        // word 1: aware
        words[1*8 + 0] = 5'd0;  // a
        words[1*8 + 1] = 5'd22; // w
        words[1*8 + 2] = 5'd0;  // a
        words[1*8 + 3] = 5'd17; // r
        words[1*8 + 4] = 5'd4;  // e

        // word 2: dish
        words[2*8 + 0] = 5'd3;  // d
        words[2*8 + 1] = 5'd8;  // i
        words[2*8 + 2] = 5'd18; // s
        words[2*8 + 3] = 5'd7;  // h

        // word 3: sink
        words[3*8 + 0] = 5'd18; // s
        words[3*8 + 1] = 5'd8;  // i
        words[3*8 + 2] = 5'd13; // n
        words[3*8 + 3] = 5'd10; // k

        // word 4: studio
        words[4*8 + 0] = 5'd18; // s
        words[4*8 + 1] = 5'd19; // t
        words[4*8 + 2] = 5'd20; // u
        words[4*8 + 3] = 5'd3;  // d
        words[4*8 + 4] = 5'd8;  // i
        words[4*8 + 5] = 5'd14; // o

        // word 5: ritual
        words[5*8 + 0] = 5'd17; // r
        words[5*8 + 1] = 5'd8;  // i
        words[5*8 + 2] = 5'd19; // t
        words[5*8 + 3] = 5'd20; // u
        words[5*8 + 4] = 5'd0;  // a
        words[5*8 + 5] = 5'd11; // l

        // word 6: week
        words[6*8 + 0] = 5'd22; // w
        words[6*8 + 1] = 5'd4;  // e
        words[6*8 + 2] = 5'd4;  // e
        words[6*8 + 3] = 5'd10; // k

        // word 7: name
        words[7*8 + 0] = 5'd13; // n
        words[7*8 + 1] = 5'd0;  // a
        words[7*8 + 2] = 5'd12; // m
        words[7*8 + 3] = 5'd4;  // e

        // word 8: lecture
        words[8*8 + 0] = 5'd11; // l
        words[8*8 + 1] = 5'd4;  // e
        words[8*8 + 2] = 5'd2;  // c
        words[8*8 + 3] = 5'd19; // t
        words[8*8 + 4] = 5'd20; // u
        words[8*8 + 5] = 5'd17; // r
        words[8*8 + 6] = 5'd4;  // e

        // word 9: hear
        words[9*8 + 0] = 5'd7;  // h
        words[9*8 + 1] = 5'd4;  // e
        words[9*8 + 2] = 5'd0;  // a
        words[9*8 + 3] = 5'd17; // r

        // word 10: sweater
        words[10*8 + 0] = 5'd18; // s
        words[10*8 + 1] = 5'd22; // w
        words[10*8 + 2] = 5'd4;  // e
        words[10*8 + 3] = 5'd0;  // a
        words[10*8 + 4] = 5'd19; // t
        words[10*8 + 5] = 5'd4;  // e
        words[10*8 + 6] = 5'd17; // r

        // word 11: glow
        words[11*8 + 0] = 5'd6;  // g
        words[11*8 + 1] = 5'd11; // l
        words[11*8 + 2] = 5'd14; // o
        words[11*8 + 3] = 5'd22; // w

        // word 12: trustee
        words[12*8 + 0] = 5'd19; // t
        words[12*8 + 1] = 5'd17; // r
        words[12*8 + 2] = 5'd20; // u
        words[12*8 + 3] = 5'd18; // s
        words[12*8 + 4] = 5'd19; // t
        words[12*8 + 5] = 5'd4;  // e
        words[12*8 + 6] = 5'd4;  // e

        // word 13: safety
        words[13*8 + 0] = 5'd18; // s
        words[13*8 + 1] = 5'd0;  // a
        words[13*8 + 2] = 5'd5;  // f
        words[13*8 + 3] = 5'd4;  // e
        words[13*8 + 4] = 5'd19; // t
        words[13*8 + 5] = 5'd24; // y

        // word 14: defend
        words[14*8 + 0] = 5'd3;  // d
        words[14*8 + 1] = 5'd4;  // e
        words[14*8 + 2] = 5'd5;  // f
        words[14*8 + 3] = 5'd4;  // e
        words[14*8 + 4] = 5'd13; // n
        words[14*8 + 5] = 5'd3;  // d

        // word 15: social
        words[15*8 + 0] = 5'd18; // s
        words[15*8 + 1] = 5'd14; // o
        words[15*8 + 2] = 5'd2;  // c
        words[15*8 + 3] = 5'd8;  // i
        words[15*8 + 4] = 5'd0;  // a
        words[15*8 + 5] = 5'd11; // l

        // word 16: peasant
        words[16*8 + 0] = 5'd15; // p
        words[16*8 + 1] = 5'd4;  // e
        words[16*8 + 2] = 5'd0;  // a
        words[16*8 + 3] = 5'd18; // s
        words[16*8 + 4] = 5'd0;  // a
        words[16*8 + 5] = 5'd13; // n
        words[16*8 + 6] = 5'd19; // t

        // word 17: export
        words[17*8 + 0] = 5'd4;  // e
        words[17*8 + 1] = 5'd23; // x
        words[17*8 + 2] = 5'd15; // p
        words[17*8 + 3] = 5'd14; // o
        words[17*8 + 4] = 5'd17; // r
        words[17*8 + 5] = 5'd19; // t

        // word 18: episode
        words[18*8 + 0] = 5'd4;  // e
        words[18*8 + 1] = 5'd15; // p
        words[18*8 + 2] = 5'd8;  // i
        words[18*8 + 3] = 5'd18; // s
        words[18*8 + 4] = 5'd14; // o
        words[18*8 + 5] = 5'd3;  // d
        words[18*8 + 6] = 5'd4;  // e

        // word 19: dome
        words[19*8 + 0] = 5'd3;  // d
        words[19*8 + 1] = 5'd14; // o
        words[19*8 + 2] = 5'd12; // m
        words[19*8 + 3] = 5'd4;  // e

        // word 20: shelf
        words[20*8 + 0] = 5'd18; // s
        words[20*8 + 1] = 5'd7;  // h
        words[20*8 + 2] = 5'd4;  // e
        words[20*8 + 3] = 5'd11; // l
        words[20*8 + 4] = 5'd5;  // f

        // word 21: delete
        words[21*8 + 0] = 5'd3;  // d
        words[21*8 + 1] = 5'd4;  // e
        words[21*8 + 2] = 5'd11; // l
        words[21*8 + 3] = 5'd4;  // e
        words[21*8 + 4] = 5'd19; // t
        words[21*8 + 5] = 5'd4;  // e

        // word 22: survey
        words[22*8 + 0] = 5'd18; // s
        words[22*8 + 1] = 5'd20; // u
        words[22*8 + 2] = 5'd17; // r
        words[22*8 + 3] = 5'd21; // v
        words[22*8 + 4] = 5'd4;  // e
        words[22*8 + 5] = 5'd24; // y

        // word 23: delay
        words[23*8 + 0] = 5'd3;  // d
        words[23*8 + 1] = 5'd4;  // e
        words[23*8 + 2] = 5'd11; // l
        words[23*8 + 3] = 5'd0;  // a
        words[23*8 + 4] = 5'd24; // y

        // word 24: march
        words[24*8 + 0] = 5'd12; // m
        words[24*8 + 1] = 5'd0;  // a
        words[24*8 + 2] = 5'd17; // r
        words[24*8 + 3] = 5'd2;  // c
        words[24*8 + 4] = 5'd7;  // h

        // word 25: excuse
        words[25*8 + 0] = 5'd4;  // e
        words[25*8 + 1] = 5'd23; // x
        words[25*8 + 2] = 5'd2;  // c
        words[25*8 + 3] = 5'd20; // u
        words[25*8 + 4] = 5'd18; // s
        words[25*8 + 5] = 5'd4;  // e

        // word 26: year
        words[26*8 + 0] = 5'd24; // y
        words[26*8 + 1] = 5'd4;  // e
        words[26*8 + 2] = 5'd0;  // a
        words[26*8 + 3] = 5'd17; // r

        // word 27: yearn
        words[27*8 + 0] = 5'd24; // y
        words[27*8 + 1] = 5'd4;  // e
        words[27*8 + 2] = 5'd0;  // a
        words[27*8 + 3] = 5'd17; // r
        words[27*8 + 4] = 5'd13; // n

        // word 28: breed
        words[28*8 + 0] = 5'd1;  // b
        words[28*8 + 1] = 5'd17; // r
        words[28*8 + 2] = 5'd4;  // e
        words[28*8 + 3] = 5'd4;  // e
        words[28*8 + 4] = 5'd3;  // d

        // word 29: cheat
        words[29*8 + 0] = 5'd2;  // c
        words[29*8 + 1] = 5'd7;  // h
        words[29*8 + 2] = 5'd4;  // e
        words[29*8 + 3] = 5'd0;  // a
        words[29*8 + 4] = 5'd19; // t

        // word 30: confuse
        words[30*8 + 0] = 5'd2;  // c
        words[30*8 + 1] = 5'd14; // o
        words[30*8 + 2] = 5'd13; // n
        words[30*8 + 3] = 5'd5;  // f
        words[30*8 + 4] = 5'd20; // u
        words[30*8 + 5] = 5'd18; // s
        words[30*8 + 6] = 5'd4;  // e

        // word 31: law
        words[31*8 + 0] = 5'd11; // l
        words[31*8 + 1] = 5'd0;  // a
        words[31*8 + 2] = 5'd22; // w

        // word 32: alarm
        words[32*8 + 0] = 5'd0;  // a
        words[32*8 + 1] = 5'd11; // l
        words[32*8 + 2] = 5'd0;  // a
        words[32*8 + 3] = 5'd17; // r
        words[32*8 + 4] = 5'd12; // m

        // word 33: tourist
        words[33*8 + 0] = 5'd19; // t
        words[33*8 + 1] = 5'd14; // o
        words[33*8 + 2] = 5'd20; // u
        words[33*8 + 3] = 5'd17; // r
        words[33*8 + 4] = 5'd8;  // i
        words[33*8 + 5] = 5'd18; // s
        words[33*8 + 6] = 5'd19; // t

        // word 34: grief
        words[34*8 + 0] = 5'd6;  // g
        words[34*8 + 1] = 5'd17; // r
        words[34*8 + 2] = 5'd8;  // i
        words[34*8 + 3] = 5'd4;  // e
        words[34*8 + 4] = 5'd5;  // f

        // word 35: crowd
        words[35*8 + 0] = 5'd2;  // c
        words[35*8 + 1] = 5'd17; // r
        words[35*8 + 2] = 5'd14; // o
        words[35*8 + 3] = 5'd22; // w
        words[35*8 + 4] = 5'd3;  // d

        // word 36: basket
        words[36*8 + 0] = 5'd1;  // b
        words[36*8 + 1] = 5'd0;  // a
        words[36*8 + 2] = 5'd18; // s
        words[36*8 + 3] = 5'd10; // k
        words[36*8 + 4] = 5'd4;  // e
        words[36*8 + 5] = 5'd19; // t

        // word 37: proper
        words[37*8 + 0] = 5'd15; // p
        words[37*8 + 1] = 5'd17; // r
        words[37*8 + 2] = 5'd14; // o
        words[37*8 + 3] = 5'd15; // p
        words[37*8 + 4] = 5'd4;  // e
        words[37*8 + 5] = 5'd17; // r

        // word 38: rear
        words[38*8 + 0] = 5'd17; // r
        words[38*8 + 1] = 5'd4;  // e
        words[38*8 + 2] = 5'd0;  // a
        words[38*8 + 3] = 5'd17; // r

        // word 39: salmon
        words[39*8 + 0] = 5'd18; // s
        words[39*8 + 1] = 5'd0;  // a
        words[39*8 + 2] = 5'd11; // l
        words[39*8 + 3] = 5'd12; // m
        words[39*8 + 4] = 5'd14; // o
        words[39*8 + 5] = 5'd13; // n
		
		// word 40: at
        words[40*8 + 0] = 5'd0;  // a
        words[40*8 + 1] = 5'd19; // t

        // word 41: on
        words[41*8 + 0] = 5'd14; // o
        words[41*8 + 1] = 5'd13; // n

        // word 42: off
        words[42*8 + 0] = 5'd14; // o
        words[42*8 + 1] = 5'd5;  // f
        words[42*8 + 2] = 5'd5;  // f

        // word 43: mix
        words[43*8 + 0] = 5'd12; // m
        words[43*8 + 1] = 5'd8;  // i
        words[43*8 + 2] = 5'd23; // x

        // word 44: grid
        words[44*8 + 0] = 5'd6;  // g
        words[44*8 + 1] = 5'd17; // r
        words[44*8 + 2] = 5'd8;  // i
        words[44*8 + 3] = 5'd3;  // d

        // word 45: code
        words[45*8 + 0] = 5'd2;  // c
        words[45*8 + 1] = 5'd14; // o
        words[45*8 + 2] = 5'd3;  // d
        words[45*8 + 3] = 5'd4;  // e

        // word 46: data
        words[46*8 + 0] = 5'd3;  // d
        words[46*8 + 1] = 5'd0;  // a
        words[46*8 + 2] = 5'd19; // t
        words[46*8 + 3] = 5'd0;  // a

        // word 47: type
        words[47*8 + 0] = 5'd19; // t
        words[47*8 + 1] = 5'd24; // y
        words[47*8 + 2] = 5'd15; // p
        words[47*8 + 3] = 5'd4;  // e

        // word 48: wave
        words[48*8 + 0] = 5'd22; // w
        words[48*8 + 1] = 5'd0;  // a
        words[48*8 + 2] = 5'd21; // v
        words[48*8 + 3] = 5'd4;  // e

        // word 49: lamp
        words[49*8 + 0] = 5'd11; // l
        words[49*8 + 1] = 5'd0;  // a
        words[49*8 + 2] = 5'd12; // m
        words[49*8 + 3] = 5'd15; // p

        // word 50: desk
        words[50*8 + 0] = 5'd3;  // d
        words[50*8 + 1] = 5'd4;  // e
        words[50*8 + 2] = 5'd18; // s
        words[50*8 + 3] = 5'd10; // k

        // word 51: door
        words[51*8 + 0] = 5'd3;  // d
        words[51*8 + 1] = 5'd14; // o
        words[51*8 + 2] = 5'd14; // o
        words[51*8 + 3] = 5'd17; // r

        // word 52: menu
        words[52*8 + 0] = 5'd12; // m
        words[52*8 + 1] = 5'd4;  // e
        words[52*8 + 2] = 5'd13; // n
        words[52*8 + 3] = 5'd20; // u

        // word 53: hall
        words[53*8 + 0] = 5'd7;  // h
        words[53*8 + 1] = 5'd0;  // a
        words[53*8 + 2] = 5'd11; // l
        words[53*8 + 3] = 5'd11; // l

        // word 54: line
        words[54*8 + 0] = 5'd11; // l
        words[54*8 + 1] = 5'd8;  // i
        words[54*8 + 2] = 5'd13; // n
        words[54*8 + 3] = 5'd4;  // e

        // word 55: path
        words[55*8 + 0] = 5'd15; // p
        words[55*8 + 1] = 5'd0;  // a
        words[55*8 + 2] = 5'd19; // t
        words[55*8 + 3] = 5'd7;  // h

        // word 56: node
        words[56*8 + 0] = 5'd13; // n
        words[56*8 + 1] = 5'd14; // o
        words[56*8 + 2] = 5'd3;  // d
        words[56*8 + 3] = 5'd4;  // e

        // word 57: wire
        words[57*8 + 0] = 5'd22; // w
        words[57*8 + 1] = 5'd8;  // i
        words[57*8 + 2] = 5'd17; // r
        words[57*8 + 3] = 5'd4;  // e

        // word 58: gain
        words[58*8 + 0] = 5'd6;  // g
        words[58*8 + 1] = 5'd0;  // a
        words[58*8 + 2] = 5'd8;  // i
        words[58*8 + 3] = 5'd13; // n

        // word 59: loss
        words[59*8 + 0] = 5'd11; // l
        words[59*8 + 1] = 5'd14; // o
        words[59*8 + 2] = 5'd18; // s
        words[59*8 + 3] = 5'd18; // s

        // word 60: alpha
        words[60*8 + 0] = 5'd0;  // a
        words[60*8 + 1] = 5'd11; // l
        words[60*8 + 2] = 5'd15; // p
        words[60*8 + 3] = 5'd7;  // h
        words[60*8 + 4] = 5'd0;  // a

        // word 61: gamma
        words[61*8 + 0] = 5'd6;  // g
        words[61*8 + 1] = 5'd0;  // a
        words[61*8 + 2] = 5'd12; // m
        words[61*8 + 3] = 5'd12; // m
        words[61*8 + 4] = 5'd0;  // a

        // word 62: delta
        words[62*8 + 0] = 5'd3;  // d
        words[62*8 + 1] = 5'd4;  // e
        words[62*8 + 2] = 5'd11; // l
        words[62*8 + 3] = 5'd19; // t
        words[62*8 + 4] = 5'd0;  // a

        // word 63: array
        words[63*8 + 0] = 5'd0;  // a
        words[63*8 + 1] = 5'd17; // r
        words[63*8 + 2] = 5'd17; // r
        words[63*8 + 3] = 5'd0;  // a
        words[63*8 + 4] = 5'd24; // y

        // word 64: while
        words[64*8 + 0] = 5'd22; // w
        words[64*8 + 1] = 5'd7;  // h
        words[64*8 + 2] = 5'd8;  // i
        words[64*8 + 3] = 5'd11; // l
        words[64*8 + 4] = 5'd4;  // e

        // word 65: stack
        words[65*8 + 0] = 5'd18; // s
        words[65*8 + 1] = 5'd19; // t
        words[65*8 + 2] = 5'd0;  // a
        words[65*8 + 3] = 5'd2;  // c
        words[65*8 + 4] = 5'd10; // k

        // word 66: queue
        words[66*8 + 0] = 5'd16; // q
        words[66*8 + 1] = 5'd20; // u
        words[66*8 + 2] = 5'd4;  // e
        words[66*8 + 3] = 5'd20; // u
        words[66*8 + 4] = 5'd4;  // e

        // word 67: input
        words[67*8 + 0] = 5'd8;  // i
        words[67*8 + 1] = 5'd13; // n
        words[67*8 + 2] = 5'd15; // p
        words[67*8 + 3] = 5'd20; // u
        words[67*8 + 4] = 5'd19; // t

        // word 68: output
        words[68*8 + 0] = 5'd14; // o
        words[68*8 + 1] = 5'd20; // u
        words[68*8 + 2] = 5'd19; // t
        words[68*8 + 3] = 5'd15; // p
        words[68*8 + 4] = 5'd20; // u
        words[68*8 + 5] = 5'd19; // t

        // word 69: pixel
        words[69*8 + 0] = 5'd15; // p
        words[69*8 + 1] = 5'd8;  // i
        words[69*8 + 2] = 5'd23; // x
        words[69*8 + 3] = 5'd4;  // e
        words[69*8 + 4] = 5'd11; // l

        // word 70: frame
        words[70*8 + 0] = 5'd5;  // f
        words[70*8 + 1] = 5'd17; // r
        words[70*8 + 2] = 5'd0;  // a
        words[70*8 + 3] = 5'd12; // m
        words[70*8 + 4] = 5'd4;  // e

        // word 71: graph
        words[71*8 + 0] = 5'd6;  // g
        words[71*8 + 1] = 5'd17; // r
        words[71*8 + 2] = 5'd0;  // a
        words[71*8 + 3] = 5'd15; // p
        words[71*8 + 4] = 5'd7;  // h

        // word 72: audio
        words[72*8 + 0] = 5'd0;  // a
        words[72*8 + 1] = 5'd20; // u
        words[72*8 + 2] = 5'd3;  // d
        words[72*8 + 3] = 5'd8;  // i
        words[72*8 + 4] = 5'd14; // o

        // word 73: video
        words[73*8 + 0] = 5'd21; // v
        words[73*8 + 1] = 5'd8;  // i
        words[73*8 + 2] = 5'd3;  // d
        words[73*8 + 3] = 5'd4;  // e
        words[73*8 + 4] = 5'd14; // o

        // word 74: mouse
        words[74*8 + 0] = 5'd12; // m
        words[74*8 + 1] = 5'd14; // o
        words[74*8 + 2] = 5'd20; // u
        words[74*8 + 3] = 5'd18; // s
        words[74*8 + 4] = 5'd4;  // e

        // word 75: touch
        words[75*8 + 0] = 5'd19; // t
        words[75*8 + 1] = 5'd14; // o
        words[75*8 + 2] = 5'd20; // u
        words[75*8 + 3] = 5'd2;  // c
        words[75*8 + 4] = 5'd7;  // h

        // word 76: space
        words[76*8 + 0] = 5'd18; // s
        words[76*8 + 1] = 5'd15; // p
        words[76*8 + 2] = 5'd0;  // a
        words[76*8 + 3] = 5'd2;  // c
        words[76*8 + 4] = 5'd4;  // e

        // word 77: earth
        words[77*8 + 0] = 5'd4;  // e
        words[77*8 + 1] = 5'd0;  // a
        words[77*8 + 2] = 5'd17; // r
        words[77*8 + 3] = 5'd19; // t
        words[77*8 + 4] = 5'd7;  // h

        // word 78: water
        words[78*8 + 0] = 5'd22; // w
        words[78*8 + 1] = 5'd0;  // a
        words[78*8 + 2] = 5'd19; // t
        words[78*8 + 3] = 5'd4;  // e
        words[78*8 + 4] = 5'd17; // r

        // word 79: metal
        words[79*8 + 0] = 5'd12; // m
        words[79*8 + 1] = 5'd4;  // e
        words[79*8 + 2] = 5'd19; // t
        words[79*8 + 3] = 5'd0;  // a
        words[79*8 + 4] = 5'd11; // l

        // word 80: stone
        words[80*8 + 0] = 5'd18; // s
        words[80*8 + 1] = 5'd19; // t
        words[80*8 + 2] = 5'd14; // o
        words[80*8 + 3] = 5'd13; // n
        words[80*8 + 4] = 5'd4;  // e

        // word 81: cloud
        words[81*8 + 0] = 5'd2;  // c
        words[81*8 + 1] = 5'd11; // l
        words[81*8 + 2] = 5'd14; // o
        words[81*8 + 3] = 5'd20; // u
        words[81*8 + 4] = 5'd3;  // d

        // word 82: storm
        words[82*8 + 0] = 5'd18; // s
        words[82*8 + 1] = 5'd19; // t
        words[82*8 + 2] = 5'd14; // o
        words[82*8 + 3] = 5'd17; // r
        words[82*8 + 4] = 5'd12; // m

        // word 83: flame
        words[83*8 + 0] = 5'd5;  // f
        words[83*8 + 1] = 5'd11; // l
        words[83*8 + 2] = 5'd0;  // a
        words[83*8 + 3] = 5'd12; // m
        words[83*8 + 4] = 5'd4;  // e

        // word 84: river
        words[84*8 + 0] = 5'd17; // r
        words[84*8 + 1] = 5'd8;  // i
        words[84*8 + 2] = 5'd21; // v
        words[84*8 + 3] = 5'd4;  // e
        words[84*8 + 4] = 5'd17; // r

        // word 85: valve
        words[85*8 + 0] = 5'd21; // v
        words[85*8 + 1] = 5'd0;  // a
        words[85*8 + 2] = 5'd11; // l
        words[85*8 + 3] = 5'd21; // v
        words[85*8 + 4] = 5'd4;  // e

        // word 86: motor
        words[86*8 + 0] = 5'd12; // m
        words[86*8 + 1] = 5'd14; // o
        words[86*8 + 2] = 5'd19; // t
        words[86*8 + 3] = 5'd14; // o
        words[86*8 + 4] = 5'd17; // r

        // word 87: sensor
        words[87*8 + 0] = 5'd18; // s
        words[87*8 + 1] = 5'd4;  // e
        words[87*8 + 2] = 5'd13; // n
        words[87*8 + 3] = 5'd18; // s
        words[87*8 + 4] = 5'd14; // o
        words[87*8 + 5] = 5'd17; // r

        // word 88: cable
        words[88*8 + 0] = 5'd2;  // c
        words[88*8 + 1] = 5'd0;  // a
        words[88*8 + 2] = 5'd1;  // b
        words[88*8 + 3] = 5'd11; // l
        words[88*8 + 4] = 5'd4;  // e

        // word 89: router
        words[89*8 + 0] = 5'd17; // r
        words[89*8 + 1] = 5'd14; // o
        words[89*8 + 2] = 5'd20; // u
        words[89*8 + 3] = 5'd19; // t
        words[89*8 + 4] = 5'd4;  // e
        words[89*8 + 5] = 5'd17; // r

        // word 90: system
        words[90*8 + 0] = 5'd18; // s
        words[90*8 + 1] = 5'd24; // y
        words[90*8 + 2] = 5'd18; // s
        words[90*8 + 3] = 5'd19; // t
        words[90*8 + 4] = 5'd4;  // e
        words[90*8 + 5] = 5'd12; // m

        // word 91: energy
        words[91*8 + 0] = 5'd4;  // e
        words[91*8 + 1] = 5'd13; // n
        words[91*8 + 2] = 5'd4;  // e
        words[91*8 + 3] = 5'd17; // r
        words[91*8 + 4] = 5'd6;  // g
        words[91*8 + 5] = 5'd24; // y

        // word 92: charge
        words[92*8 + 0] = 5'd2;  // c
        words[92*8 + 1] = 5'd7;  // h
        words[92*8 + 2] = 5'd0;  // a
        words[92*8 + 3] = 5'd17; // r
        words[92*8 + 4] = 5'd6;  // g
        words[92*8 + 5] = 5'd4;  // e

        // word 93: travel
        words[93*8 + 0] = 5'd19; // t
        words[93*8 + 1] = 5'd17; // r
        words[93*8 + 2] = 5'd0;  // a
        words[93*8 + 3] = 5'd21; // v
        words[93*8 + 4] = 5'd4;  // e
        words[93*8 + 5] = 5'd11; // l

        // word 94: flight
        words[94*8 + 0] = 5'd5;  // f
        words[94*8 + 1] = 5'd11; // l
        words[94*8 + 2] = 5'd8;  // i
        words[94*8 + 3] = 5'd6;  // g
        words[94*8 + 4] = 5'd7;  // h
        words[94*8 + 5] = 5'd19; // t

        // word 95: ticket
        words[95*8 + 0] = 5'd19; // t
        words[95*8 + 1] = 5'd8;  // i
        words[95*8 + 2] = 5'd2;  // c
        words[95*8 + 3] = 5'd10; // k
        words[95*8 + 4] = 5'd4;  // e
        words[95*8 + 5] = 5'd19; // t

        // word 96: pillow
        words[96*8 + 0] = 5'd15; // p
        words[96*8 + 1] = 5'd8;  // i
        words[96*8 + 2] = 5'd11; // l
        words[96*8 + 3] = 5'd11; // l
        words[96*8 + 4] = 5'd14; // o
        words[96*8 + 5] = 5'd22; // w

        // word 97: mirror
        words[97*8 + 0] = 5'd12; // m
        words[97*8 + 1] = 5'd8;  // i
        words[97*8 + 2] = 5'd17; // r
        words[97*8 + 3] = 5'd17; // r
        words[97*8 + 4] = 5'd14; // o
        words[97*8 + 5] = 5'd17; // r

        // word 98: pocket
        words[98*8 + 0] = 5'd15; // p
        words[98*8 + 1] = 5'd14; // o
        words[98*8 + 2] = 5'd2;  // c
        words[98*8 + 3] = 5'd10; // k
        words[98*8 + 4] = 5'd4;  // e
        words[98*8 + 5] = 5'd19; // t

        // word 99: wallet
        words[99*8 + 0] = 5'd22; // w
        words[99*8 + 1] = 5'd0;  // a
        words[99*8 + 2] = 5'd11; // l
        words[99*8 + 3] = 5'd11; // l
        words[99*8 + 4] = 5'd4;  // e
        words[99*8 + 5] = 5'd19; // t
        // word 100: monitor
        words[100*8 + 0] = 5'd12; // m
        words[100*8 + 1] = 5'd14; // o
        words[100*8 + 2] = 5'd13; // n
        words[100*8 + 3] = 5'd8;  // i
        words[100*8 + 4] = 5'd19; // t
        words[100*8 + 5] = 5'd14; // o
        words[100*8 + 6] = 5'd17; // r

        // word 101: display
        words[101*8 + 0] = 5'd3;  // d
        words[101*8 + 1] = 5'd8;  // i
        words[101*8 + 2] = 5'd18; // s
        words[101*8 + 3] = 5'd15; // p
        words[101*8 + 4] = 5'd11; // l
        words[101*8 + 5] = 5'd0;  // a
        words[101*8 + 6] = 5'd24; // y

        // word 102: student
        words[102*8 + 0] = 5'd18; // s
        words[102*8 + 1] = 5'd19; // t
        words[102*8 + 2] = 5'd20; // u
        words[102*8 + 3] = 5'd3;  // d
        words[102*8 + 4] = 5'd4;  // e
        words[102*8 + 5] = 5'd13; // n
        words[102*8 + 6] = 5'd19; // t

        // word 103: battery
        words[103*8 + 0] = 5'd1;  // b
        words[103*8 + 1] = 5'd0;  // a
        words[103*8 + 2] = 5'd19; // t
        words[103*8 + 3] = 5'd19; // t
        words[103*8 + 4] = 5'd4;  // e
        words[103*8 + 5] = 5'd17; // r
        words[103*8 + 6] = 5'd24; // y

        // word 104: current
        words[104*8 + 0] = 5'd2;  // c
        words[104*8 + 1] = 5'd20; // u
        words[104*8 + 2] = 5'd17; // r
        words[104*8 + 3] = 5'd17; // r
        words[104*8 + 4] = 5'd4;  // e
        words[104*8 + 5] = 5'd13; // n
        words[104*8 + 6] = 5'd19; // t

        // word 105: voltage
        words[105*8 + 0] = 5'd21; // v
        words[105*8 + 1] = 5'd14; // o
        words[105*8 + 2] = 5'd11; // l
        words[105*8 + 3] = 5'd19; // t
        words[105*8 + 4] = 5'd0;  // a
        words[105*8 + 5] = 5'd6;  // g
        words[105*8 + 6] = 5'd4;  // e

        // word 106: network
        words[106*8 + 0] = 5'd13; // n
        words[106*8 + 1] = 5'd4;  // e
        words[106*8 + 2] = 5'd19; // t
        words[106*8 + 3] = 5'd22; // w
        words[106*8 + 4] = 5'd14; // o
        words[106*8 + 5] = 5'd17; // r
        words[106*8 + 6] = 5'd10; // k

        // word 107: storage
        words[107*8 + 0] = 5'd18; // s
        words[107*8 + 1] = 5'd19; // t
        words[107*8 + 2] = 5'd14; // o
        words[107*8 + 3] = 5'd17; // r
        words[107*8 + 4] = 5'd0;  // a
        words[107*8 + 5] = 5'd6;  // g
        words[107*8 + 6] = 5'd4;  // e

        // word 108: project
        words[108*8 + 0] = 5'd15; // p
        words[108*8 + 1] = 5'd17; // r
        words[108*8 + 2] = 5'd14; // o
        words[108*8 + 3] = 5'd9;  // j
        words[108*8 + 4] = 5'd4;  // e
        words[108*8 + 5] = 5'd2;  // c
        words[108*8 + 6] = 5'd19; // t

        // word 109: channel
        words[109*8 + 0] = 5'd2;  // c
        words[109*8 + 1] = 5'd7;  // h
        words[109*8 + 2] = 5'd0;  // a
        words[109*8 + 3] = 5'd13; // n
        words[109*8 + 4] = 5'd13; // n
        words[109*8 + 5] = 5'd4;  // e
        words[109*8 + 6] = 5'd11; // l

        // word 110: pointer
        words[110*8 + 0] = 5'd15; // p
        words[110*8 + 1] = 5'd14; // o
        words[110*8 + 2] = 5'd8;  // i
        words[110*8 + 3] = 5'd13; // n
        words[110*8 + 4] = 5'd19; // t
        words[110*8 + 5] = 5'd4;  // e
        words[110*8 + 6] = 5'd17; // r

        // word 111: segment
        words[111*8 + 0] = 5'd18; // s
        words[111*8 + 1] = 5'd4;  // e
        words[111*8 + 2] = 5'd6;  // g
        words[111*8 + 3] = 5'd12; // m
        words[111*8 + 4] = 5'd4;  // e
        words[111*8 + 5] = 5'd13; // n
        words[111*8 + 6] = 5'd19; // t

        // word 112: numeric
        words[112*8 + 0] = 5'd13; // n
        words[112*8 + 1] = 5'd20; // u
        words[112*8 + 2] = 5'd12; // m
        words[112*8 + 3] = 5'd4;  // e
        words[112*8 + 4] = 5'd17; // r
        words[112*8 + 5] = 5'd8;  // i
        words[112*8 + 6] = 5'd2;  // c

        // word 113: logical
        words[113*8 + 0] = 5'd11; // l
        words[113*8 + 1] = 5'd14; // o
        words[113*8 + 2] = 5'd6;  // g
        words[113*8 + 3] = 5'd8;  // i
        words[113*8 + 4] = 5'd2;  // c
        words[113*8 + 5] = 5'd0;  // a
        words[113*8 + 6] = 5'd11; // l

        // word 114: freedom
        words[114*8 + 0] = 5'd5;  // f
        words[114*8 + 1] = 5'd17; // r
        words[114*8 + 2] = 5'd4;  // e
        words[114*8 + 3] = 5'd4;  // e
        words[114*8 + 4] = 5'd3;  // d
        words[114*8 + 5] = 5'd14; // o
        words[114*8 + 6] = 5'd12; // m

        // word 115: imagine
        words[115*8 + 0] = 5'd8;  // i
        words[115*8 + 1] = 5'd12; // m
        words[115*8 + 2] = 5'd0;  // a
        words[115*8 + 3] = 5'd6;  // g
        words[115*8 + 4] = 5'd8;  // i
        words[115*8 + 5] = 5'd13; // n
        words[115*8 + 6] = 5'd4;  // e

        // word 116: teacher
        words[116*8 + 0] = 5'd19; // t
        words[116*8 + 1] = 5'd4;  // e
        words[116*8 + 2] = 5'd0;  // a
        words[116*8 + 3] = 5'd2;  // c
        words[116*8 + 4] = 5'd7;  // h
        words[116*8 + 5] = 5'd4;  // e
        words[116*8 + 6] = 5'd17; // r

        // word 117: section
        words[117*8 + 0] = 5'd18; // s
        words[117*8 + 1] = 5'd4;  // e
        words[117*8 + 2] = 5'd2;  // c
        words[117*8 + 3] = 5'd19; // t
        words[117*8 + 4] = 5'd8;  // i
        words[117*8 + 5] = 5'd14; // o
        words[117*8 + 6] = 5'd13; // n

        // word 118: context
        words[118*8 + 0] = 5'd2;  // c
        words[118*8 + 1] = 5'd14; // o
        words[118*8 + 2] = 5'd13; // n
        words[118*8 + 3] = 5'd19; // t
        words[118*8 + 4] = 5'd4;  // e
        words[118*8 + 5] = 5'd23; // x
        words[118*8 + 6] = 5'd19; // t

        // word 119: problem
        words[119*8 + 0] = 5'd15; // p
        words[119*8 + 1] = 5'd17; // r
        words[119*8 + 2] = 5'd14; // o
        words[119*8 + 3] = 5'd1;  // b
        words[119*8 + 4] = 5'd11; // l
        words[119*8 + 5] = 5'd4;  // e
        words[119*8 + 6] = 5'd12; // m

        // word 120: journal
        words[120*8 + 0] = 5'd9;  // j
        words[120*8 + 1] = 5'd14; // o
        words[120*8 + 2] = 5'd20; // u
        words[120*8 + 3] = 5'd17; // r
        words[120*8 + 4] = 5'd13; // n
        words[120*8 + 5] = 5'd0;  // a
        words[120*8 + 6] = 5'd11; // l

        // word 121: factory
        words[121*8 + 0] = 5'd5;  // f
        words[121*8 + 1] = 5'd0;  // a
        words[121*8 + 2] = 5'd2;  // c
        words[121*8 + 3] = 5'd19; // t
        words[121*8 + 4] = 5'd14; // o
        words[121*8 + 5] = 5'd17; // r
        words[121*8 + 6] = 5'd24; // y

        // word 122: circuit
        words[122*8 + 0] = 5'd2;  // c
        words[122*8 + 1] = 5'd8;  // i
        words[122*8 + 2] = 5'd17; // r
        words[122*8 + 3] = 5'd2;  // c
        words[122*8 + 4] = 5'd20; // u
        words[122*8 + 5] = 5'd8;  // i
        words[122*8 + 6] = 5'd19; // t

        // word 123: console
        words[123*8 + 0] = 5'd2;  // c
        words[123*8 + 1] = 5'd14; // o
        words[123*8 + 2] = 5'd13; // n
        words[123*8 + 3] = 5'd18; // s
        words[123*8 + 4] = 5'd14; // o
        words[123*8 + 5] = 5'd11; // l
        words[123*8 + 6] = 5'd4;  // e

        // word 124: warning
        words[124*8 + 0] = 5'd22; // w
        words[124*8 + 1] = 5'd0;  // a
        words[124*8 + 2] = 5'd17; // r
        words[124*8 + 3] = 5'd13; // n
        words[124*8 + 4] = 5'd8;  // i
        words[124*8 + 5] = 5'd13; // n
        words[124*8 + 6] = 5'd6;  // g

        // word 125: message
        words[125*8 + 0] = 5'd12; // m
        words[125*8 + 1] = 5'd4;  // e
        words[125*8 + 2] = 5'd18; // s
        words[125*8 + 3] = 5'd18; // s
        words[125*8 + 4] = 5'd0;  // a
        words[125*8 + 5] = 5'd6;  // g
        words[125*8 + 6] = 5'd4;  // e

        // word 126: history
        words[126*8 + 0] = 5'd7;  // h
        words[126*8 + 1] = 5'd8;  // i
        words[126*8 + 2] = 5'd18; // s
        words[126*8 + 3] = 5'd19; // t
        words[126*8 + 4] = 5'd14; // o
        words[126*8 + 5] = 5'd17; // r
        words[126*8 + 6] = 5'd24; // y

        // word 127: gravity
        words[127*8 + 0] = 5'd6;  // g
        words[127*8 + 1] = 5'd17; // r
        words[127*8 + 2] = 5'd0;  // a
        words[127*8 + 3] = 5'd21; // v
        words[127*8 + 4] = 5'd8;  // i
        words[127*8 + 5] = 5'd19; // t
        words[127*8 + 6] = 5'd24; // y

        // word 128: pattern
        words[128*8 + 0] = 5'd15; // p
        words[128*8 + 1] = 5'd0;  // a
        words[128*8 + 2] = 5'd19; // t
        words[128*8 + 3] = 5'd19; // t
        words[128*8 + 4] = 5'd4;  // e
        words[128*8 + 5] = 5'd17; // r
        words[128*8 + 6] = 5'd13; // n

        // word 129: surface
        words[129*8 + 0] = 5'd18; // s
        words[129*8 + 1] = 5'd20; // u
        words[129*8 + 2] = 5'd17; // r
        words[129*8 + 3] = 5'd5;  // f
        words[129*8 + 4] = 5'd0;  // a
        words[129*8 + 5] = 5'd2;  // c
        words[129*8 + 6] = 5'd4;  // e

        // word 130: feature
        words[130*8 + 0] = 5'd5;  // f
        words[130*8 + 1] = 5'd4;  // e
        words[130*8 + 2] = 5'd0;  // a
        words[130*8 + 3] = 5'd19; // t
        words[130*8 + 4] = 5'd20; // u
        words[130*8 + 5] = 5'd17; // r
        words[130*8 + 6] = 5'd4;  // e

        // word 131: balance
        words[131*8 + 0] = 5'd1;  // b
        words[131*8 + 1] = 5'd0;  // a
        words[131*8 + 2] = 5'd11; // l
        words[131*8 + 3] = 5'd0;  // a
        words[131*8 + 4] = 5'd13; // n
        words[131*8 + 5] = 5'd2;  // c
        words[131*8 + 6] = 5'd4;  // e

        // word 132: housing
        words[132*8 + 0] = 5'd7;  // h
        words[132*8 + 1] = 5'd14; // o
        words[132*8 + 2] = 5'd20; // u
        words[132*8 + 3] = 5'd18; // s
        words[132*8 + 4] = 5'd8;  // i
        words[132*8 + 5] = 5'd13; // n
        words[132*8 + 6] = 5'd6;  // g

        // word 133: sibling
        words[133*8 + 0] = 5'd18; // s
        words[133*8 + 1] = 5'd8;  // i
        words[133*8 + 2] = 5'd1;  // b
        words[133*8 + 3] = 5'd11; // l
        words[133*8 + 4] = 5'd8;  // i
        words[133*8 + 5] = 5'd13; // n
        words[133*8 + 6] = 5'd6;  // g

        // word 134: crystal
        words[134*8 + 0] = 5'd2;  // c
        words[134*8 + 1] = 5'd17; // r
        words[134*8 + 2] = 5'd24; // y
        words[134*8 + 3] = 5'd18; // s
        words[134*8 + 4] = 5'd19; // t
        words[134*8 + 5] = 5'd0;  // a
        words[134*8 + 6] = 5'd11; // l

        // word 135: gateway
        words[135*8 + 0] = 5'd6;  // g
        words[135*8 + 1] = 5'd0;  // a
        words[135*8 + 2] = 5'd19; // t
        words[135*8 + 3] = 5'd4;  // e
        words[135*8 + 4] = 5'd22; // w
        words[135*8 + 5] = 5'd0;  // a
        words[135*8 + 6] = 5'd24; // y

        // word 136: between
        words[136*8 + 0] = 5'd1;  // b
        words[136*8 + 1] = 5'd4;  // e
        words[136*8 + 2] = 5'd19; // t
        words[136*8 + 3] = 5'd22; // w
        words[136*8 + 4] = 5'd4;  // e
        words[136*8 + 5] = 5'd4;  // e
        words[136*8 + 6] = 5'd13; // n

        // word 137: digital
        words[137*8 + 0] = 5'd3;  // d
        words[137*8 + 1] = 5'd8;  // i
        words[137*8 + 2] = 5'd6;  // g
        words[137*8 + 3] = 5'd8;  // i
        words[137*8 + 4] = 5'd19; // t
        words[137*8 + 5] = 5'd0;  // a
        words[137*8 + 6] = 5'd11; // l

        // word 138: antenna
        words[138*8 + 0] = 5'd0;  // a
        words[138*8 + 1] = 5'd13; // n
        words[138*8 + 2] = 5'd19; // t
        words[138*8 + 3] = 5'd4;  // e
        words[138*8 + 4] = 5'd13; // n
        words[138*8 + 5] = 5'd13; // n
        words[138*8 + 6] = 5'd0;  // a

        // word 139: receive
        words[139*8 + 0] = 5'd17; // r
        words[139*8 + 1] = 5'd4;  // e
        words[139*8 + 2] = 5'd2;  // c
        words[139*8 + 3] = 5'd4;  // e
        words[139*8 + 4] = 5'd8;  // i
        words[139*8 + 5] = 5'd21; // v
        words[139*8 + 6] = 5'd4;  // e

        // word 140: transmit
        words[140*8 + 0] = 5'd19; // t
        words[140*8 + 1] = 5'd17; // r
        words[140*8 + 2] = 5'd0;  // a
        words[140*8 + 3] = 5'd13; // n
        words[140*8 + 4] = 5'd18; // s
        words[140*8 + 5] = 5'd12; // m
        words[140*8 + 6] = 5'd8;  // i
        words[140*8 + 7] = 5'd19; // t

        // word 141: printer
        words[141*8 + 0] = 5'd15; // p
        words[141*8 + 1] = 5'd17; // r
        words[141*8 + 2] = 5'd8;  // i
        words[141*8 + 3] = 5'd13; // n
        words[141*8 + 4] = 5'd19; // t
        words[141*8 + 5] = 5'd4;  // e
        words[141*8 + 6] = 5'd17; // r

        // word 142: compute
        words[142*8 + 0] = 5'd2;  // c
        words[142*8 + 1] = 5'd14; // o
        words[142*8 + 2] = 5'd12; // m
        words[142*8 + 3] = 5'd15; // p
        words[142*8 + 4] = 5'd20; // u
        words[142*8 + 5] = 5'd19; // t
        words[142*8 + 6] = 5'd4;  // e

        // word 143: control
        words[143*8 + 0] = 5'd2;  // c
        words[143*8 + 1] = 5'd14; // o
        words[143*8 + 2] = 5'd13; // n
        words[143*8 + 3] = 5'd19; // t
        words[143*8 + 4] = 5'd17; // r
        words[143*8 + 5] = 5'd14; // o
        words[143*8 + 6] = 5'd11; // l

        // word 144: science
        words[144*8 + 0] = 5'd18; // s
        words[144*8 + 1] = 5'd2;  // c
        words[144*8 + 2] = 5'd8;  // i
        words[144*8 + 3] = 5'd4;  // e
        words[144*8 + 4] = 5'd13; // n
        words[144*8 + 5] = 5'd2;  // c
        words[144*8 + 6] = 5'd4;  // e

        // word 145: physics
        words[145*8 + 0] = 5'd15; // p
        words[145*8 + 1] = 5'd7;  // h
        words[145*8 + 2] = 5'd24; // y
        words[145*8 + 3] = 5'd18; // s
        words[145*8 + 4] = 5'd8;  // i
        words[145*8 + 5] = 5'd2;  // c
        words[145*8 + 6] = 5'd18; // s

        // word 146: algebra
        words[146*8 + 0] = 5'd0;  // a
        words[146*8 + 1] = 5'd11; // l
        words[146*8 + 2] = 5'd6;  // g
        words[146*8 + 3] = 5'd4;  // e
        words[146*8 + 4] = 5'd1;  // b
        words[146*8 + 5] = 5'd17; // r
        words[146*8 + 6] = 5'd0;  // a

        // word 147: complex
        words[147*8 + 0] = 5'd2;  // c
        words[147*8 + 1] = 5'd14; // o
        words[147*8 + 2] = 5'd12; // m
        words[147*8 + 3] = 5'd15; // p
        words[147*8 + 4] = 5'd11; // l
        words[147*8 + 5] = 5'd4;  // e
        words[147*8 + 6] = 5'd23; // x

        // word 148: traction
        words[148*8 + 0] = 5'd19; // t
        words[148*8 + 1] = 5'd17; // r
        words[148*8 + 2] = 5'd0;  // a
        words[148*8 + 3] = 5'd2;  // c
        words[148*8 + 4] = 5'd19; // t
        words[148*8 + 5] = 5'd8;  // i
        words[148*8 + 6] = 5'd14; // o
        words[148*8 + 7] = 5'd13; // n

        // word 149: velocity
        words[149*8 + 0] = 5'd21; // v
        words[149*8 + 1] = 5'd4;  // e
        words[149*8 + 2] = 5'd11; // l
        words[149*8 + 3] = 5'd14; // o
        words[149*8 + 4] = 5'd2;  // c
        words[149*8 + 5] = 5'd8;  // i
        words[149*8 + 6] = 5'd19; // t
        words[149*8 + 7] = 5'd24; // y

        // word 150: timeout
        words[150*8 + 0] = 5'd19; // t
        words[150*8 + 1] = 5'd8;  // i
        words[150*8 + 2] = 5'd12; // m
        words[150*8 + 3] = 5'd4;  // e
        words[150*8 + 4] = 5'd14; // o
        words[150*8 + 5] = 5'd20; // u
        words[150*8 + 6] = 5'd19; // t

        // word 151: counter
        words[151*8 + 0] = 5'd2;  // c
        words[151*8 + 1] = 5'd14; // o
        words[151*8 + 2] = 5'd20; // u
        words[151*8 + 3] = 5'd13; // n
        words[151*8 + 4] = 5'd19; // t
        words[151*8 + 5] = 5'd4;  // e
        words[151*8 + 6] = 5'd17; // r

        // word 152: refresh
        words[152*8 + 0] = 5'd17; // r
        words[152*8 + 1] = 5'd4;  // e
        words[152*8 + 2] = 5'd5;  // f
        words[152*8 + 3] = 5'd17; // r
        words[152*8 + 4] = 5'd4;  // e
        words[152*8 + 5] = 5'd18; // s
        words[152*8 + 6] = 5'd7;  // h

        // word 153: toolkit
        words[153*8 + 0] = 5'd19; // t
        words[153*8 + 1] = 5'd14; // o
        words[153*8 + 2] = 5'd14; // o
        words[153*8 + 3] = 5'd11; // l
        words[153*8 + 4] = 5'd10; // k
        words[153*8 + 5] = 5'd8;  // i
        words[153*8 + 6] = 5'd19; // t

        // word 154: profile
        words[154*8 + 0] = 5'd15; // p
        words[154*8 + 1] = 5'd17; // r
        words[154*8 + 2] = 5'd14; // o
        words[154*8 + 3] = 5'd5;  // f
        words[154*8 + 4] = 5'd8;  // i
        words[154*8 + 5] = 5'd11; // l
        words[154*8 + 6] = 5'd4;  // e

        // word 155: address
        words[155*8 + 0] = 5'd0;  // a
        words[155*8 + 1] = 5'd3;  // d
        words[155*8 + 2] = 5'd3;  // d
        words[155*8 + 3] = 5'd17; // r
        words[155*8 + 4] = 5'd4;  // e
        words[155*8 + 5] = 5'd18; // s
        words[155*8 + 6] = 5'd18; // s

        // word 156: package
        words[156*8 + 0] = 5'd15; // p
        words[156*8 + 1] = 5'd0;  // a
        words[156*8 + 2] = 5'd2;  // c
        words[156*8 + 3] = 5'd10; // k
        words[156*8 + 4] = 5'd0;  // a
        words[156*8 + 5] = 5'd6;  // g
        words[156*8 + 6] = 5'd4;  // e

        // word 157: resolve
        words[157*8 + 0] = 5'd17; // r
        words[157*8 + 1] = 5'd4;  // e
        words[157*8 + 2] = 5'd18; // s
        words[157*8 + 3] = 5'd14; // o
        words[157*8 + 4] = 5'd11; // l
        words[157*8 + 5] = 5'd21; // v
        words[157*8 + 6] = 5'd4;  // e

        // word 158: attempt
        words[158*8 + 0] = 5'd0;  // a
        words[158*8 + 1] = 5'd19; // t
        words[158*8 + 2] = 5'd19; // t
        words[158*8 + 3] = 5'd4;  // e
        words[158*8 + 4] = 5'd12; // m
        words[158*8 + 5] = 5'd15; // p
        words[158*8 + 6] = 5'd19; // t

        // word 159: command
        words[159*8 + 0] = 5'd2;  // c
        words[159*8 + 1] = 5'd14; // o
        words[159*8 + 2] = 5'd12; // m
        words[159*8 + 3] = 5'd12; // m
        words[159*8 + 4] = 5'd0;  // a
        words[159*8 + 5] = 5'd13; // n
        words[159*8 + 6] = 5'd3;  // d

        // word 160: inspect
        words[160*8 + 0] = 5'd8;  // i
        words[160*8 + 1] = 5'd13; // n
        words[160*8 + 2] = 5'd18; // s
        words[160*8 + 3] = 5'd15; // p
        words[160*8 + 4] = 5'd4;  // e
        words[160*8 + 5] = 5'd2;  // c
        words[160*8 + 6] = 5'd19; // t

        // word 161: comfort
        words[161*8 + 0] = 5'd2;  // c
        words[161*8 + 1] = 5'd14; // o
        words[161*8 + 2] = 5'd12; // m
        words[161*8 + 3] = 5'd5;  // f
        words[161*8 + 4] = 5'd14; // o
        words[161*8 + 5] = 5'd17; // r
        words[161*8 + 6] = 5'd19; // t

        // word 162: fiction
        words[162*8 + 0] = 5'd5;  // f
        words[162*8 + 1] = 5'd8;  // i
        words[162*8 + 2] = 5'd2;  // c
        words[162*8 + 3] = 5'd19; // t
        words[162*8 + 4] = 5'd8;  // i
        words[162*8 + 5] = 5'd14; // o
        words[162*8 + 6] = 5'd13; // n

        // word 163: correct
        words[163*8 + 0] = 5'd2;  // c
        words[163*8 + 1] = 5'd14; // o
        words[163*8 + 2] = 5'd17; // r
        words[163*8 + 3] = 5'd17; // r
        words[163*8 + 4] = 5'd4;  // e
        words[163*8 + 5] = 5'd2;  // c
        words[163*8 + 6] = 5'd19; // t

        // word 164: perform
        words[164*8 + 0] = 5'd15; // p
        words[164*8 + 1] = 5'd4;  // e
        words[164*8 + 2] = 5'd17; // r
        words[164*8 + 3] = 5'd5;  // f
        words[164*8 + 4] = 5'd14; // o
        words[164*8 + 5] = 5'd17; // r
        words[164*8 + 6] = 5'd12; // m

        // word 165: failure
        words[165*8 + 0] = 5'd5;  // f
        words[165*8 + 1] = 5'd0;  // a
        words[165*8 + 2] = 5'd8;  // i
        words[165*8 + 3] = 5'd11; // l
        words[165*8 + 4] = 5'd20; // u
        words[165*8 + 5] = 5'd17; // r
        words[165*8 + 6] = 5'd4;  // e

        // word 166: success
        words[166*8 + 0] = 5'd18; // s
        words[166*8 + 1] = 5'd20; // u
        words[166*8 + 2] = 5'd2;  // c
        words[166*8 + 3] = 5'd2;  // c
        words[166*8 + 4] = 5'd4;  // e
        words[166*8 + 5] = 5'd18; // s
        words[166*8 + 6] = 5'd18; // s

        // word 167: restart
        words[167*8 + 0] = 5'd17; // r
        words[167*8 + 1] = 5'd4;  // e
        words[167*8 + 2] = 5'd18; // s
        words[167*8 + 3] = 5'd19; // t
        words[167*8 + 4] = 5'd0;  // a
        words[167*8 + 5] = 5'd17; // r
        words[167*8 + 6] = 5'd19; // t

        // word 168: recover
        words[168*8 + 0] = 5'd17; // r
        words[168*8 + 1] = 5'd4;  // e
        words[168*8 + 2] = 5'd2;  // c
        words[168*8 + 3] = 5'd14; // o
        words[168*8 + 4] = 5'd21; // v
        words[168*8 + 5] = 5'd4;  // e
        words[168*8 + 6] = 5'd17; // r

        // word 169: collect
        words[169*8 + 0] = 5'd2;  // c
        words[169*8 + 1] = 5'd14; // o
        words[169*8 + 2] = 5'd11; // l
        words[169*8 + 3] = 5'd11; // l
        words[169*8 + 4] = 5'd4;  // e
        words[169*8 + 5] = 5'd2;  // c
        words[169*8 + 6] = 5'd19; // t

        // word 170: confirm
        words[170*8 + 0] = 5'd2;  // c
        words[170*8 + 1] = 5'd14; // o
        words[170*8 + 2] = 5'd13; // n
        words[170*8 + 3] = 5'd5;  // f
        words[170*8 + 4] = 5'd8;  // i
        words[170*8 + 5] = 5'd17; // r
        words[170*8 + 6] = 5'd12; // m

        // word 171: compare
        words[171*8 + 0] = 5'd2;  // c
        words[171*8 + 1] = 5'd14; // o
        words[171*8 + 2] = 5'd12; // m
        words[171*8 + 3] = 5'd15; // p
        words[171*8 + 4] = 5'd0;  // a
        words[171*8 + 5] = 5'd17; // r
        words[171*8 + 6] = 5'd4;  // e

        // word 172: include
        words[172*8 + 0] = 5'd8;  // i
        words[172*8 + 1] = 5'd13; // n
        words[172*8 + 2] = 5'd2;  // c
        words[172*8 + 3] = 5'd11; // l
        words[172*8 + 4] = 5'd20; // u
        words[172*8 + 5] = 5'd3;  // d
        words[172*8 + 6] = 5'd4;  // e

        // word 173: exclude
        words[173*8 + 0] = 5'd4;  // e
        words[173*8 + 1] = 5'd23; // x
        words[173*8 + 2] = 5'd2;  // c
        words[173*8 + 3] = 5'd11; // l
        words[173*8 + 4] = 5'd20; // u
        words[173*8 + 5] = 5'd3;  // d
        words[173*8 + 6] = 5'd4;  // e

        // word 174: summary
        words[174*8 + 0] = 5'd18; // s
        words[174*8 + 1] = 5'd20; // u
        words[174*8 + 2] = 5'd12; // m
        words[174*8 + 3] = 5'd12; // m
        words[174*8 + 4] = 5'd0;  // a
        words[174*8 + 5] = 5'd17; // r
        words[174*8 + 6] = 5'd24; // y

        // word 175: develop
        words[175*8 + 0] = 5'd3;  // d
        words[175*8 + 1] = 5'd4;  // e
        words[175*8 + 2] = 5'd21; // v
        words[175*8 + 3] = 5'd4;  // e
        words[175*8 + 4] = 5'd11; // l
        words[175*8 + 5] = 5'd14; // o
        words[175*8 + 6] = 5'd15; // p

        // word 176: enhance
        words[176*8 + 0] = 5'd4;  // e
        words[176*8 + 1] = 5'd13; // n
        words[176*8 + 2] = 5'd7;  // h
        words[176*8 + 3] = 5'd0;  // a
        words[176*8 + 4] = 5'd13; // n
        words[176*8 + 5] = 5'd2;  // c
        words[176*8 + 6] = 5'd4;  // e

        // word 177: upgrade
        words[177*8 + 0] = 5'd20; // u
        words[177*8 + 1] = 5'd15; // p
        words[177*8 + 2] = 5'd6;  // g
        words[177*8 + 3] = 5'd17; // r
        words[177*8 + 4] = 5'd0;  // a
        words[177*8 + 5] = 5'd3;  // d
        words[177*8 + 6] = 5'd4;  // e

        // word 178: version
        words[178*8 + 0] = 5'd21; // v
        words[178*8 + 1] = 5'd4;  // e
        words[178*8 + 2] = 5'd17; // r
        words[178*8 + 3] = 5'd18; // s
        words[178*8 + 4] = 5'd8;  // i
        words[178*8 + 5] = 5'd14; // o
        words[178*8 + 6] = 5'd13; // n

        // word 179: mapping
        words[179*8 + 0] = 5'd12; // m
        words[179*8 + 1] = 5'd0;  // a
        words[179*8 + 2] = 5'd15; // p
        words[179*8 + 3] = 5'd15; // p
        words[179*8 + 4] = 5'd8;  // i
        words[179*8 + 5] = 5'd13; // n
        words[179*8 + 6] = 5'd6;  // g

        // word 180: minimum
        words[180*8 + 0] = 5'd12; // m
        words[180*8 + 1] = 5'd8;  // i
        words[180*8 + 2] = 5'd13; // n
        words[180*8 + 3] = 5'd8;  // i
        words[180*8 + 4] = 5'd12; // m
        words[180*8 + 5] = 5'd20; // u
        words[180*8 + 6] = 5'd12; // m

        // word 181: maximum
        words[181*8 + 0] = 5'd12; // m
        words[181*8 + 1] = 5'd0;  // a
        words[181*8 + 2] = 5'd23; // x
        words[181*8 + 3] = 5'd8;  // i
        words[181*8 + 4] = 5'd12; // m
        words[181*8 + 5] = 5'd20; // u
        words[181*8 + 6] = 5'd12; // m

        // word 182: average
        words[182*8 + 0] = 5'd0;  // a
        words[182*8 + 1] = 5'd21; // v
        words[182*8 + 2] = 5'd4;  // e
        words[182*8 + 3] = 5'd17; // r
        words[182*8 + 4] = 5'd0;  // a
        words[182*8 + 5] = 5'd6;  // g
        words[182*8 + 6] = 5'd4;  // e

        // word 183: uniform
        words[183*8 + 0] = 5'd20; // u
        words[183*8 + 1] = 5'd13; // n
        words[183*8 + 2] = 5'd8;  // i
        words[183*8 + 3] = 5'd5;  // f
        words[183*8 + 4] = 5'd14; // o
        words[183*8 + 5] = 5'd17; // r
        words[183*8 + 6] = 5'd12; // m

        // word 184: variant
        words[184*8 + 0] = 5'd21; // v
        words[184*8 + 1] = 5'd0;  // a
        words[184*8 + 2] = 5'd17; // r
        words[184*8 + 3] = 5'd8;  // i
        words[184*8 + 4] = 5'd0;  // a
        words[184*8 + 5] = 5'd13; // n
        words[184*8 + 6] = 5'd19; // t

        // word 185: formula
        words[185*8 + 0] = 5'd5;  // f
        words[185*8 + 1] = 5'd14; // o
        words[185*8 + 2] = 5'd17; // r
        words[185*8 + 3] = 5'd12; // m
        words[185*8 + 4] = 5'd20; // u
        words[185*8 + 5] = 5'd11; // l
        words[185*8 + 6] = 5'd0;  // a

        // word 186: radical
        words[186*8 + 0] = 5'd17; // r
        words[186*8 + 1] = 5'd0;  // a
        words[186*8 + 2] = 5'd3;  // d
        words[186*8 + 3] = 5'd8;  // i
        words[186*8 + 4] = 5'd2;  // c
        words[186*8 + 5] = 5'd0;  // a
        words[186*8 + 6] = 5'd11; // l

        // word 187: integer
        words[187*8 + 0] = 5'd8;  // i
        words[187*8 + 1] = 5'd13; // n
        words[187*8 + 2] = 5'd19; // t
        words[187*8 + 3] = 5'd4;  // e
        words[187*8 + 4] = 5'd6;  // g
        words[187*8 + 5] = 5'd4;  // e
        words[187*8 + 6] = 5'd17; // r

        // word 188: decimal
        words[188*8 + 0] = 5'd3;  // d
        words[188*8 + 1] = 5'd4;  // e
        words[188*8 + 2] = 5'd2;  // c
        words[188*8 + 3] = 5'd8;  // i
        words[188*8 + 4] = 5'd12; // m
        words[188*8 + 5] = 5'd0;  // a
        words[188*8 + 6] = 5'd11; // l

        // word 189: proceed
        words[189*8 + 0] = 5'd15; // p
        words[189*8 + 1] = 5'd17; // r
        words[189*8 + 2] = 5'd14; // o
        words[189*8 + 3] = 5'd2;  // c
        words[189*8 + 4] = 5'd4;  // e
        words[189*8 + 5] = 5'd4;  // e
        words[189*8 + 6] = 5'd3;  // d

        // word 190: capture
        words[190*8 + 0] = 5'd2;  // c
        words[190*8 + 1] = 5'd0;  // a
        words[190*8 + 2] = 5'd15; // p
        words[190*8 + 3] = 5'd19; // t
        words[190*8 + 4] = 5'd20; // u
        words[190*8 + 5] = 5'd17; // r
        words[190*8 + 6] = 5'd4;  // e

        // word 191: picture
        words[191*8 + 0] = 5'd15; // p
        words[191*8 + 1] = 5'd8;  // i
        words[191*8 + 2] = 5'd2;  // c
        words[191*8 + 3] = 5'd19; // t
        words[191*8 + 4] = 5'd20; // u
        words[191*8 + 5] = 5'd17; // r
        words[191*8 + 6] = 5'd4;  // e

        // word 192: diagram
        words[192*8 + 0] = 5'd3;  // d
        words[192*8 + 1] = 5'd8;  // i
        words[192*8 + 2] = 5'd0;  // a
        words[192*8 + 3] = 5'd6;  // g
        words[192*8 + 4] = 5'd17; // r
        words[192*8 + 5] = 5'd0;  // a
        words[192*8 + 6] = 5'd12; // m

        // word 193: concept
        words[193*8 + 0] = 5'd2;  // c
        words[193*8 + 1] = 5'd14; // o
        words[193*8 + 2] = 5'd13; // n
        words[193*8 + 3] = 5'd2;  // c
        words[193*8 + 4] = 5'd4;  // e
        words[193*8 + 5] = 5'd15; // p
        words[193*8 + 6] = 5'd19; // t

        // word 194: process
        words[194*8 + 0] = 5'd15; // p
        words[194*8 + 1] = 5'd17; // r
        words[194*8 + 2] = 5'd14; // o
        words[194*8 + 3] = 5'd2;  // c
        words[194*8 + 4] = 5'd4;  // e
        words[194*8 + 5] = 5'd18; // s
        words[194*8 + 6] = 5'd18; // s

        // word 195: neutral
        words[195*8 + 0] = 5'd13; // n
        words[195*8 + 1] = 5'd4;  // e
        words[195*8 + 2] = 5'd20; // u
        words[195*8 + 3] = 5'd19; // t
        words[195*8 + 4] = 5'd17; // r
        words[195*8 + 5] = 5'd0;  // a
        words[195*8 + 6] = 5'd11; // l

        // word 196: dynamic
        words[196*8 + 0] = 5'd3;  // d
        words[196*8 + 1] = 5'd24; // y
        words[196*8 + 2] = 5'd13; // n
        words[196*8 + 3] = 5'd0;  // a
        words[196*8 + 4] = 5'd12; // m
        words[196*8 + 5] = 5'd8;  // i
        words[196*8 + 6] = 5'd2;  // c

        // word 197: static
        words[197*8 + 0] = 5'd18; // s
        words[197*8 + 1] = 5'd19; // t
        words[197*8 + 2] = 5'd0;  // a
        words[197*8 + 3] = 5'd19; // t
        words[197*8 + 4] = 5'd8;  // i
        words[197*8 + 5] = 5'd2;  // c

        // word 198: resistor
        words[198*8 + 0] = 5'd17; // r
        words[198*8 + 1] = 5'd4;  // e
        words[198*8 + 2] = 5'd18; // s
        words[198*8 + 3] = 5'd8;  // i
        words[198*8 + 4] = 5'd18; // s
        words[198*8 + 5] = 5'd19; // t
        words[198*8 + 6] = 5'd14; // o
        words[198*8 + 7] = 5'd17; // r

        // word 199: inductor
        words[199*8 + 0] = 5'd8;  // i
        words[199*8 + 1] = 5'd13; // n
        words[199*8 + 2] = 5'd3;  // d
        words[199*8 + 3] = 5'd20; // u
        words[199*8 + 4] = 5'd2;  // c
        words[199*8 + 5] = 5'd19; // t
        words[199*8 + 6] = 5'd14; // o
        words[199*8 + 7] = 5'd17; // r

    end

  // RANDOMIZATION LOGIC 
    
    // Instantiate randomizer
    wire [7:0] rand_word_idx;
    wire rand_ready;
    wire rand_done;
    
    word_randomizer RAND (
        .clock(clock),
        .resetn(resetn),
        .reshuffle(reshuffle),
        .get_next(1'b0),
        .word_index(rand_word_idx),
        .index_ready(rand_ready),
        .shuffle_done(rand_done)
    );
    
    // Store random word order (49 words to display from 200 total)
    reg [7:0] word_order [0:48];    // 49 words
    reg [5:0] capture_count;
    reg capturing;
    
    // Capture random indices when shuffling
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            capturing <= 1'b0;
            capture_count <= 6'd0;
        end else begin
            if (reshuffle) begin
                capturing <= 1'b1;
                capture_count <= 6'd0;
            end
            
            if (capturing && rand_ready && capture_count < 6'd49) begin
                word_order[capture_count] <= rand_word_idx;
                capture_count <= capture_count + 6'd1;
            end
            
            if (rand_done || capture_count >= 6'd49) begin
                capturing <= 1'b0;
            end
        end
    end
    
    // END RANDOMIZATION LOGIC 
	
    // indices and flag
    reg [5:0] word_number;     // 0..48 (49 words)
    reg [2:0] letter_number;   // 0..7
    reg       sending_space;
    reg       enable_send_d;   // delayed request
    
    // Map position to actual random word
    wire [7:0] actual_word;
    assign actual_word = word_order[word_number];
    
    // Calculate 1D index from actual_word and letter_number
    wire [9:0] word_index;
    wire [9:0] next_index;
    assign word_index = (actual_word * n_letters) + letter_number;
    assign next_index = (actual_word * n_letters) + letter_number + 1;
    
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            word_number    <= 0;
            letter_number  <= 0;
            sending_space  <= 0;
            char_sent      <= LETTER_SPACE;
            letter_ready   <= 1'b0;
            enable_send_d  <= 1'b0;
        end else begin
            // 1-cycle delay of enable_send
            enable_send_d <= enable_send;
            // default
            letter_ready <= 1'b0;
            // advance text stream only when requested
            if (enable_send) begin
                if (sending_space) begin
                    // output the inter-word space
                    char_sent     <= LETTER_SPACE;
                    sending_space <= 1'b0;
                    // move to next word
                    if (word_number == 6'd48)  // 49 words (0-48)
                        word_number <= 0;
                    else
                        word_number <= word_number + 1;
                end else begin
                    // send current character
                    char_sent     <= words[word_index];
                    
                    // increment letter position
                    letter_number <= letter_number + 1;
                    
                    // check if NEXT position will be terminator or end of array
                    if ((letter_number == (n_letters - 1)) || (words[next_index] == LETTER_SPACE)) begin
                        // Next char is terminator or we're at end, so word is done
                        sending_space <= 1'b1;   // next request will send a space
                        letter_number <= 0;      // reset for next word (overrides the increment above)
                    end
                end
            end
            // READY pulse one cycle after enable_send (when char_sent is stable)
            if (enable_send_d)
                letter_ready <= 1'b1;
        end
    end
endmodule