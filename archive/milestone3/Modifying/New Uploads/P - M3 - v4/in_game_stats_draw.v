module in_game_stats_draw(
    cerr_tens, cerr_ones, werr_tens, werr_ones,
    stats_valid,    // one-time start/enable pulse or level
    clock, resetn,
    cerr_col, cerr_row,
    werr_col, werr_row,
    num_address, num_color9,
    x, y, color, write,
    busy, done,
    cerr_hundreds, werr_hundreds
);
    // DIGITS
    input [3:0] cerr_tens, cerr_ones, cerr_hundreds;
    input [3:0] werr_tens, werr_ones, werr_hundreds;

    input stats_valid;
    input clock, resetn;

    // TEXT BOX POSITIONS (LEFT DIGIT)
    input [9:0] cerr_col, cerr_row;
    input [9:0] werr_col, werr_row;

    // PER-STAT MARGINS
    parameter WERR_H_MARGIN = 195;
    parameter WERR_V_MARGIN = 420;

    parameter CERR_H_MARGIN = 420;
    parameter CERR_V_MARGIN = 420;

    parameter CHAR_H    = 8;
    parameter CHAR_W    = 8;
    parameter IMAGE_W   = 80;
    parameter SCALE     = 3;

    // CHANGED: 3-bit colors
    parameter [2:0] BACKGROUND_COLOR = 3'b000;  // clear color
    parameter [2:0] STAT_COLOR       = 3'b111;  // digit color (white)

    // DIGIT FONT ROM
    output reg [9:0] num_address;
    input      [2:0] num_color9;   // CHANGED: 3-bit

    // VGA OUTPUTS
    output reg [9:0] x, y;
    output reg [2:0] color;        // CHANGED: 3-bit
    output reg write;
    output reg busy;
    output reg done;

    // DERIVED CONSTANTS
    wire [9:0] DRAW_W = CHAR_W * SCALE;
    wire [9:0] DRAW_H = CHAR_H * SCALE;

    // FSM STATES
    parameter IDLE     = 3'd0;
    parameter SETUP    = 3'd1;
    parameter READ     = 3'd2;
    parameter DRAW     = 3'd3;
    parameter NEXT_PX  = 3'd4;
    parameter NEXT_ROW = 3'd5;
    parameter DONE_ST  = 3'd6;   // CHANGED: used as frame-done pulse

    reg [2:0] Y;  // current state

    // REGISTERS
    reg [9:0] base_x, base_y;
    reg [9:0] fx, fy;
    reg [1:0] sx, sy;
    reg [19:0] base_address;
    reg [19:0] row_base_address;
    reg [2:0] px_color;           // CHANGED: 3-bit

    // WHICH STAT (0=char err, 1=word err) AND WHICH DIGIT
    reg [1:0] stat_index;
    reg [1:0] digit_index;

    // SELECTED DIGIT AND TEXT-GRID POSITION
    reg [3:0] selected_digit;
    reg [9:0] selected_col;
    reg [9:0] selected_row;

    // CURRENT MARGINS FOR THIS STAT
    reg [9:0] current_h_margin;
    reg [9:0] current_v_margin;

    // COMBINATIONAL: PICK DIGIT, POSITION, MARGINS
    always @(*) begin
        selected_digit   = 4'd0;
        selected_col     = 10'd0;
        selected_row     = 10'd0;
        current_h_margin = 10'd0;
        current_v_margin = 10'd0;

        case (stat_index)
            2'd0: begin
                // CHARACTER ERRORS
                selected_row     = cerr_row;
                selected_col     = cerr_col + digit_index;
                current_h_margin = CERR_H_MARGIN;
                current_v_margin = CERR_V_MARGIN;
                case (digit_index)
                    2'd0: selected_digit = cerr_hundreds;
                    2'd1: selected_digit = cerr_tens;
                    2'd2: selected_digit = cerr_ones;
                    default: selected_digit = 4'd0;
                endcase
            end

            2'd1: begin
                // WORD ERRORS
                selected_row     = werr_row;
                selected_col     = werr_col + digit_index;
                current_h_margin = WERR_H_MARGIN;
                current_v_margin = WERR_V_MARGIN;
                case (digit_index)
                    2'd0: selected_digit = werr_hundreds;
                    2'd1: selected_digit = werr_tens;
                    2'd2: selected_digit = werr_ones;
                    default: selected_digit = 4'd0;
                endcase
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
            color <= 3'd0;         // CHANGED: 3-bit reset

            base_x <= 10'd0;
            base_y <= 10'd0;

            fx <= 10'd0;
            fy <= 10'd0;
            sx <= 2'd0;
            sy <= 2'd0;

            base_address     <= 20'd0;
            row_base_address <= 20'd0;
            px_color         <= 3'd0;  // CHANGED: 3-bit reset

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
                        stat_index  <= 2'd0;
                        digit_index <= 2'd0;

                        fx <= 10'd0;
                        fy <= 10'd0;
                        sx <= 2'd0;
                        sy <= 2'd0;

                        Y <= SETUP;
                    end
                end

                SETUP: begin
                    base_x <= current_h_margin + selected_col * DRAW_W;
                    base_y <= current_v_margin + selected_row * DRAW_H;

                    base_address     <= selected_digit * CHAR_W;
                    row_base_address <= selected_digit * CHAR_W;
                    num_address      <= selected_digit * CHAR_W;

                    Y <= READ;
                end

                READ: begin
                    px_color <= num_color9;   // CHANGED: 3-bit sample
                    Y <= DRAW;
                end

                DRAW: begin
                    x <= base_x + (fx * SCALE) + sx;
                    y <= base_y + (fy * SCALE) + sy;

                    if (px_color != BACKGROUND_COLOR)
                        color <= STAT_COLOR;
                    else
                        color <= BACKGROUND_COLOR;

                    write <= 1'b1;

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
                        if (digit_index == 2'd2) begin
                            if (stat_index == 2'd1) begin
                                // CHANGED: finished last digit of last stat -> go to DONE_ST
                                Y <= DONE_ST;
                            end else begin
                                // next stat, reset digit index
                                stat_index  <= stat_index + 2'd1;
                                digit_index <= 2'd0;

                                fx <= 10'd0;
                                fy <= 10'd0;
                                sx <= 2'd0;
                                sy <= 2'd0;

                                Y <= SETUP;
                            end
                        end else begin
                            // next digit of same stat
                            digit_index <= digit_index + 2'd1;

                            fx <= 10'd0;
                            fy <= 10'd0;
                            sx <= 2'd0;
                            sy <= 2'd0;

                            Y <= SETUP;
                        end
                    end else begin
                        fy <= fy + 10'd1;
                        row_base_address <= row_base_address + IMAGE_W;
                        num_address      <= row_base_address + IMAGE_W;
                        Y <= READ;
                    end
                end

                // CHANGED: proper one-shot done + return to IDLE
                DONE_ST: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;       // one-cycle done pulse
                    stat_index  <= 2'd0; // reset for next run
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
