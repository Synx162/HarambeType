`default_nettype none

// PS/2 receiver with extended ready pulse (20 cycles)
module ps2_receiver (CLOCK_50, Resetn, PS2_CLK, PS2_DAT, scancode, ps2_rec);

    input  wire CLOCK_50;       
    input  wire Resetn;         
    inout  wire PS2_CLK;
    inout  wire PS2_DAT;
    output wire [7:0] scancode;
    output wire ps2_rec;
    wire PS2_CLK_S, PS2_DAT_S;
    reg  prev_ps2_clk;
    wire negedge_ps2_clk;

    // synchronize the PS/2 signals with CLOCK_50 
    sync S3 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
    sync S4 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

    always @(posedge CLOCK_50)
        if (!Resetn)
            prev_ps2_clk <= 1'b0;
        else
            prev_ps2_clk <= PS2_CLK_S;

    assign negedge_ps2_clk = (prev_ps2_clk & !PS2_CLK_S);

    // 33-bit shift register 
    reg [32:0] Serial;
    always @(posedge CLOCK_50) begin
        if (!Resetn)
            Serial <= 33'b0;
        else if (negedge_ps2_clk) begin
            Serial[31:0] <= Serial[32:1];
            Serial[32]   <= PS2_DAT_S;
        end
    end

    // bit counter to 11
    reg [3:0] Packet;
    always @(posedge CLOCK_50) begin
        if (!Resetn || Packet == 4'd11)
            Packet <= 4'd0;
        else if (negedge_ps2_clk)
            Packet <= Packet + 4'd1;
    end

    // byte-ready strobe - original 1-cycle pulse
    wire ps2_rec_short;
    assign ps2_rec_short = (Packet == 4'd11) && (Serial[30:23] == Serial[8:1]);

    // extend pulse to 20 cycles
    pulse_extender_20 EXT (.clock(CLOCK_50), .resetn(Resetn), .pulse_in(ps2_rec_short), .pulse_out(ps2_rec));

    // latch last received PS/2 scancode in Serial[8:1]
    regn USC (Serial[8:1], Resetn, ps2_rec_short, CLOCK_50, scancode);

endmodule

// Pulse extender - extends 1-cycle pulse to 20 cycles
module pulse_extender_20(clock, resetn, pulse_in, pulse_out);
    input  wire clock;
    input  wire resetn;
    input  wire pulse_in;
    output reg  pulse_out;
    reg [4:0] counter;
    
    always @(posedge clock, negedge resetn) begin
        if (!resetn) begin // reset low, zero out the counter and pulse
            counter <= 5'd0;
            pulse_out <= 1'b0;
        end else begin
            if (pulse_in && counter == 5'd0) begin // if we have a pulse and the counter is at 0, star
                counter <= 5'd1;
                pulse_out <= 1'b1;
            end else if (counter > 5'd0) begin // since pulse in is just a one-cycle strobe, check if the counter is greater than zero and keep incrementing till 19
                if (counter == 5'd19) begin // if we reached 20-cycles then zero out
                    counter <= 5'd0;
                    pulse_out <= 1'b0;
                end else begin // otherwise, keep incrementing by one and sending a pulse
                    counter <= counter + 5'd1; 
                    pulse_out <= 1'b1;
                end
            end
        end
    end

endmodule

// 2-FF synchronizer
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;
    reg Qi;

    always @(posedge Clock)
        if (Resetn == 0) begin
            Qi <= 1'b0;
            Q  <= 1'b0;
        end
        else begin
            Qi <= D;
            Q  <= Qi;
        end
endmodule

// 8-bit register with enable
module regn(R, Resetn, E, Clock, Q);
    input  wire [7:0] R;
    input  wire Resetn, E, Clock;
    output reg  [7:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 8'b0;
        else if (E)
            Q <= R;
endmodule