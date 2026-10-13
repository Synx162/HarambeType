module target_words (clock, resetn, enable_send, char_sent, letter_ready);

    input clock, resetn;

    parameter integer n_letters = 8;    // num of letters incl. terminator
    parameter integer n_words   = 40;   // num of words
    parameter [4:0] LETTER_SPACE = 5'd26;

    // FIXED: Declare as a single 1D array with calculated indices
    reg [4:0] words [0:(n_words * n_letters)-1];

    integer i, j;

    input  wire       enable_send;    // one-cycle request for next char
    output reg [4:0]  char_sent;      // letter index out
    output reg        letter_ready;   // 1-cycle pulse when char_sent is valid

    // init table
    initial begin
        // default: everything = space (acts as terminator)
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
    end

    // indices and flag
    reg [5:0] word_number;     // 0..39
    reg [2:0] letter_number;   // 0..7
    reg       sending_space;
    reg       enable_send_d;   // delayed request

    // Calculate 1D index from word_number and letter_number
    wire [9:0] word_index;
    wire [9:0] next_index;
    assign word_index = (word_number * n_letters) + letter_number;
    assign next_index = word_index + 1;

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
                    if (word_number == n_words - 1)
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