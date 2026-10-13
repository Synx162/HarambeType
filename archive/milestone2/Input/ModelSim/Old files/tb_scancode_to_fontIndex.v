`timescale 1ns/1ps
`default_nettype none

module tb_scancode_to_fontIndex;

  // 50 MHz clock
  reg clock = 1'b0;
  always #10 clock = ~clock; // 20 ns period

  // reset (active-low)
  reg resetn;

  // DUT inputs
  reg  [7:0] sc;
  reg        sc_rdy;

  // DUT outputs
  wire [7:0] inputChar;
  wire       inputChar_rdy;

  // DUT
  scancode_to_fontIndex dut (
    .clock(clock),
    .resetn(resetn),
    .sc(sc),
    .sc_rdy(sc_rdy),
    .inputChar(inputChar),
    .inputChar_rdy(inputChar_rdy)
  );

  // 1-cycle sc_rdy helper
  task send_byte(input [7:0] b);
  begin
    @(negedge clock);
    sc     <= b;
    sc_rdy <= 1'b1;
    @(negedge clock);
    sc_rdy <= 1'b0;
  end
  endtask

  // simple monitor
  always @(posedge clock) if (inputChar_rdy)
    $display("[%0t ns] make -> inputChar=%0d (0x%0h)", $time, inputChar, inputChar);

  // optional safety assertion: no pulses outside BASE
  localparam S_BASE=2'd0, S_GOTF0=2'd1, S_GOTE0=2'd2, S_GOTE0F0=2'd3;
  always @(posedge clock) if (resetn)
    if (dut.y != S_BASE && inputChar_rdy)
      $fatal(1, "ERROR: pulse outside BASE state!");

  initial begin
    // init
    sc      = 8'h00;
    sc_rdy  = 1'b0;
    resetn  = 1'b0;
    repeat (4) @(negedge clock);
    resetn  = 1'b1;

    // 1) MAKE 'a' (1C) -> expect 0 and a 1-cycle pulse
    send_byte(8'h1C);
    repeat (2) @(negedge clock);

    // 2) BREAK 'a' F0,1C -> expect NO pulse
    send_byte(8'hF0);
    send_byte(8'h1C);
    repeat (3) @(negedge clock);

    // 3) digit '3' (26) -> expect 29
    send_byte(8'h26);
    repeat (2) @(negedge clock);

    // 4) space (29) -> 36
    send_byte(8'h29);
    repeat (2) @(negedge clock);

    // 5) enter (5A) -> 49
    send_byte(8'h5A);
    repeat (2) @(negedge clock);

    // 6) '-' (4E) -> 38
    send_byte(8'h4E);
    repeat (2) @(negedge clock);

    // 7) extended make E0,75 (Up) -> ignore both
    send_byte(8'hE0);
    send_byte(8'h75);
    repeat (2) @(negedge clock);

    // 8) extended break E0,F0,75 -> ignore all
    send_byte(8'hE0);
    send_byte(8'hF0);
    send_byte(8'h75);
    repeat (6) @(negedge clock);

    $display("TB finished at %0t ns", $time);
    $stop;
  end

endmodule
