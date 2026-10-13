`default_nettype none

// ------------------------------------------------------------------------------------
// ps2_receiver.v

// ------------------------------------------------------------------------------------
module ps2_receiver (
    input  wire CLOCK_50,       // same clock name as demo
    input  wire Resetn,         // same active-low reset name as demo
    inout  wire PS2_CLK,
    inout  wire PS2_DAT,
    output wire [7:0] scancode, // last received PS/2 byte (demo’s regn output)
    output wire ps2_rec         // 1-cycle strobe when a byte is ready (demo’s condition)
);

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

    // (from demo) byte-ready strobe:
    // checks that we have 11 bits and current byte equals previous one
    assign ps2_rec = (Packet == 4'd11); //;&& (Serial[30:23] == Serial[8:1]);

    // (from demo) latch last received PS/2 scancode in Serial[8:1]
    regn #(.n(8)) USC (Serial[8:1], Resetn, ps2_rec, CLOCK_50, scancode);

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
