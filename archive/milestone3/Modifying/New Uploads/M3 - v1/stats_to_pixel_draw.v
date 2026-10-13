module stats_to_pixel_draw(acc_tens, acc_ones, werr_tens, werr_ones, cerr_tens, cerr_ones, wpm_tens, wpm_ones,

    stats_valid, // enabled when the game is over and the background has switched
	clock, resetn,
    acc_col,  acc_row,
    werr_col, werr_row,
    cerr_col, cerr_row,
    wpm_col,  wpm_row,
    num_address, num_color9,
    x, y, color, write,
    busy, done );
	
    // DIGITS
    input [3:0] acc_tens, acc_ones;
    input [3:0] werr_tens, werr_ones;
    input [3:0] cerr_tens, cerr_ones;
    input [3:0] wpm_tens, wpm_ones;

    input stats_valid;
    input clock, resetn;

    // TEXT BOX POSITIONS
    input [9:0] acc_col,  acc_row;
    input [9:0] werr_col, werr_row;
    input [9:0] cerr_col, cerr_row;
    input [9:0] wpm_col,  wpm_row;

    // PARAMETERS 
    parameter ACC_H_MARGIN = 440;
    parameter ACC_V_MARGIN = 140;

    parameter WERR_H_MARGIN = 440;
    parameter WERR_V_MARGIN = 225;

    parameter CERR_H_MARGIN = 440;
    parameter CERR_V_MARGIN = 315;

    parameter WPM_H_MARGIN = 440;
    parameter WPM_V_MARGIN = 400;

    parameter CHAR_H = 8;
    parameter CHAR_W = 8;
    parameter IMAGE_W = 80;
    parameter SCALE = 3;

    parameter [8:0] BACKGROUND_COLOR = 9'b000000000;
    parameter [8:0] STAT_COLOR = 9'b111111000;  // yellow

    // DIGIT FONT ROM
    output reg [9:0] num_address;
    input [8:0] num_color9;

    // VGA OUTPUTS
    output reg [9:0] x, y;
    output reg [8:0] color;
    output reg write;
    output reg busy;
    output reg done;

    // DERIVED CONSTANTS
    wire [9:0] DRAW_W = CHAR_W * SCALE;
    wire [9:0] DRAW_H = CHAR_H * SCALE;

    // FSM STATES
    parameter IDLE = 3'd0;
    parameter SETUP = 3'd1;
    parameter READ = 3'd2;
    parameter DRAW = 3'd3;
    parameter NEXT_PX = 3'd4;
    parameter NEXT_ROW = 3'd5;
    parameter DONE_ST = 3'd6;

    reg [2:0] Y;  // current state

    // REGISTERS
    reg [9:0] base_x, base_y;
    reg [9:0] fx, fy;
    reg [1:0] sx, sy;
    reg [19:0] base_address;
    reg [19:0] row_base_address;
    reg [8:0] px_color;

    // WHICH STAT & WHICH DIGIT (0=tens, 1=ones)
    reg [1:0] stat_index;
    reg [1:0] digit_index;

    // SELECTED DIGIT AND TEXT-GRID POSITION
    reg [3:0] selected_digit;
    reg [9:0] selected_col;
    reg [9:0] selected_row;

    // CURRENT MARGINS FOR THIS STAT
    reg [9:0] current_h_margin;
    reg [9:0] current_v_margin;

    // COMBINATIONAL: PICK DIGIT AND LOCATION FOR CURRENT stat_index/digit_index
    always @(*) begin
        selected_digit = 4'd0;
        selected_col = 10'd0;
        selected_row = 10'd0;
        current_h_margin = 10'd0;
        current_v_margin = 10'd0;

        case (stat_index)
            2'd0: begin
                // ACCURACY
                selected_row     = acc_row;
                selected_col     = acc_col + digit_index;
                current_h_margin = ACC_H_MARGIN;
                current_v_margin = ACC_V_MARGIN;
                if (digit_index == 2'd0)
                    selected_digit = acc_tens;
                else
                    selected_digit = acc_ones;
            end

            2'd1: begin
                // TOTAL WORD ERRORS
                selected_row     = werr_row;
                selected_col     = werr_col + digit_index;
                current_h_margin = WERR_H_MARGIN;
                current_v_margin = WERR_V_MARGIN;
                if (digit_index == 2'd0)
                    selected_digit = werr_tens;
                else
                    selected_digit = werr_ones;
            end

            2'd2: begin
                // TOTAL CHARACTER ERRORS
                selected_row     = cerr_row;
                selected_col     = cerr_col + digit_index;
                current_h_margin = CERR_H_MARGIN;
                current_v_margin = CERR_V_MARGIN;
                if (digit_index == 2'd0)
                    selected_digit = cerr_tens;
                else
                    selected_digit = cerr_ones;
            end

            2'd3: begin
                // WORDS PER MINUTE
                selected_row     = wpm_row;
                selected_col     = wpm_col + digit_index;
                current_h_margin = WPM_H_MARGIN;
                current_v_margin = WPM_V_MARGIN;
                if (digit_index == 2'd0)
                    selected_digit = wpm_tens;
                else
                    selected_digit = wpm_ones;
            end

            default: begin
                selected_digit   = 4'd0;
                selected_col     = 10'd0;
                selected_row     = 10'd0;
                current_h_margin = 10'd0;
                current_v_margin = 10'd0;
            end
        endcase
    end

    // FSM
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            Y <= IDLE;

            busy  <= 1'b0;
            done  <= 1'b0;
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

            base_address     <= 20'd0;
            row_base_address <= 20'd0;
            px_color         <= 9'd0;

            num_address <= 10'd0;
            stat_index  <= 2'd0;
            digit_index <= 2'd0;
        end else begin
            write <= 1'b0;
            done  <= 1'b0;

            case (Y)
                IDLE: begin
                    busy <= 1'b0;
                    if (stats_valid) begin
                        busy        <= 1'b1;
                        stat_index  <= 2'd0;  // start at ACCURACY
                        digit_index <= 2'd0;  // tens digit first

                        fx <= 10'd0;
                        fy <= 10'd0;
                        sx <= 2'd0;
                        sy <= 2'd0;

                        Y <= SETUP;
                    end
                end

                SETUP: begin
                    // position current digit on screen (per-stat margins)
                    base_x <= current_h_margin + selected_col * DRAW_W;
                    base_y <= current_v_margin + selected_row * DRAW_H;

                    // first address in MIF for this digit
                    base_address     <= selected_digit * CHAR_W;
                    row_base_address <= selected_digit * CHAR_W;
                    num_address      <= selected_digit * CHAR_W;

                    Y <= READ;
                end

                READ: begin
                    px_color <= num_color9;
                    Y <= DRAW;
                end

                DRAW: begin
                    if (px_color != BACKGROUND_COLOR) begin
                        x <= base_x + (fx * SCALE) + sx;
                        y <= base_y + (fy * SCALE) + sy;
                        color <= STAT_COLOR;   // always yellow
                        write <= 1'b1;
                    end

                    // scaling loop
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
                    if (fx == (CHAR_W - 1)) begin
                        fx <= 10'd0;
                        Y  <= NEXT_ROW;
                    end else begin
                        fx <= fx + 10'd1;
                        num_address <= row_base_address + fx + 10'd1;
                        Y <= READ;
                    end
                end

                NEXT_ROW: begin
                    if (fy == (CHAR_H - 1)) begin
                        // finished this digit
                        if (digit_index == 2'd1) begin
                            // finished both digits for this stat
                            if (stat_index == 2'd3) begin
                                // all 4 stats done
                                Y <= DONE_ST;
                            end else begin
                                // next stat, back to tens digit
                                stat_index  <= stat_index + 2'd1;
                                digit_index <= 2'd0;

                                fx <= 10'd0;
                                fy <= 10'd0;
                                sx <= 2'd0;
                                sy <= 2'd0;

                                Y <= SETUP;
                            end
                        end else begin
                            // move to ones digit of same stat
                            digit_index <= digit_index + 2'd1;

                            fx <= 10'd0;
                            fy <= 10'd0;
                            sx <= 2'd0;
                            sy <= 2'd0;

                            Y <= SETUP;
                        end
                    end else begin
                        // next row of same digit
                        fy <= fy + 10'd1;
                        row_base_address <= row_base_address + IMAGE_W;
                        num_address      <= row_base_address + IMAGE_W;
                        Y <= READ;
                    end
                end

                DONE_ST: begin
                    busy <= 1'b0;
                    done <= 1'b1;

                    stat_index  <= 2'd0;
                    digit_index <= 2'd0;

                    Y <= IDLE;
                end

                default: begin
                    Y <= IDLE;
                end
            endcase
        end
    end

endmodule
