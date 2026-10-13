`default_nettype none
// ps2_receiver.v - WITH EXTENDED PULSE (20 cycles)

module ps2_receiver (CLOCK_50, Resetn, PS2_CLK, PS2_DAT, scancode, ps2_rec);

    input  wire CLOCK_50;      // same clock name as demo
    input  wire Resetn;         // same active-low reset name as demo
    inout  wire PS2_CLK;
    inout  wire PS2_DAT;
    output wire [7:0] scancode; // last received PS/2 byte (demo's regn output)
    output wire ps2_rec;         // EXTENDED 20-cycle strobe when a byte is ready

    // ----- (from demo) sync + edges + shift + counter -----
    wire PS2_CLK_S, PS2_DAT_S;     // synchronized PS/2 lines
    reg  prev_ps2_clk;             // previous synced clock
    wire negedge_ps2_clk;          // falling edge detect

    // synchronize the PS/2 signals with CLOCK_50  (same as demo)
    sync S3 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
    sync S4 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

    always @(posedge CLOCK_50)
        if (!Resetn)
            prev_ps2_clk <= 1'b0;
        else
            prev_ps2_clk <= PS2_CLK_S;

    assign negedge_ps2_clk = (prev_ps2_clk & !PS2_CLK_S);

    // 33-bit shift register (same as demo)
    reg [32:0] Serial;
    always @(posedge CLOCK_50) begin
        if (!Resetn)
            Serial <= 33'b0;
        else if (negedge_ps2_clk) begin
            Serial[31:0] <= Serial[32:1];
            Serial[32]   <= PS2_DAT_S;
        end
    end

    // bit counter to 11 (same as demo)
    reg [3:0] Packet;
    always @(posedge CLOCK_50) begin
        if (!Resetn || Packet == 4'd11)
            Packet <= 4'd0;
        else if (negedge_ps2_clk)
            Packet <= Packet + 4'd1;
    end

    // (from demo) byte-ready strobe - original 1-cycle pulse
    wire ps2_rec_short;
    assign ps2_rec_short = (Packet == 4'd11);

    // EXTENDED PULSE - holds ps2_rec high for 20 cycles
    pulse_extender #(.CYCLES(20)) EXT (
        .clock(CLOCK_50),
        .resetn(Resetn),
        .pulse_in(ps2_rec_short),
        .pulse_out(ps2_rec)
    );

    // (from demo) latch last received PS/2 scancode in Serial[8:1]
    // Use the short pulse to latch once
    regn #(.n(8)) USC (Serial[8:1], Resetn, ps2_rec_short, CLOCK_50, scancode);

endmodule

// ----- Pulse Extender Module -----
module pulse_extender #(
    parameter CYCLES = 20
)(
    input  wire clock,
    input  wire resetn,
    input  wire pulse_in,    // 1-cycle input pulse
    output reg  pulse_out    // extended output pulse
);

    reg [4:0] counter;  // counts up to CYCLES (5 bits = up to 31)
    
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            counter <= 5'd0;
            pulse_out <= 1'b0;
        end else begin
            if (pulse_in && counter == 5'd0) begin
                // Start of new pulse
                counter <= 5'd1;
                pulse_out <= 1'b1;
            end else if (counter > 5'd0) begin
                // Pulse is active, count up
                if (counter == CYCLES - 1) begin
                    // End of extended pulse
                    counter <= 5'd0;
                    pulse_out <= 1'b0;
                end else begin
                    counter <= counter + 5'd1;
                    pulse_out <= 1'b1;
                end
            end
        end
    end

endmodule

// ----- (from demo) 2-FF synchronizer -----
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;

    reg Qi; // internal

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

// ----- (from demo) n-bit register with enable -----
module regn(R, Resetn, E, Clock, Q);
    parameter n = 8;
    input  wire [n-1:0] R;
    input  wire         Resetn, E, Clock;
    output reg  [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= {n{1'b0}};
        else if (E)
            Q <= R;
endmodule