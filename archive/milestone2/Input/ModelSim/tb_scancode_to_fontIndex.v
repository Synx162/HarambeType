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
  localparam BASE=2'd0, GOTF0=2'd1, GOTE0=2'd2, GOTE0F0=2'd3;
  always @(posedge clock) if (resetn)
    if (dut.y != BASE && inputChar_rdy)
      $fatal(1, "ERROR: pulse outside BASE state!");

  initial begin
    // init
    sc      = 8'h00;
    sc_rdy  = 1'b0;
    resetn  = 1'b0;
    repeat (4) @(negedge clock);
    resetn  = 1'b1;

    // No extra cycles needed - no synchronizer anymore
    repeat (2) @(negedge clock);

    // 1) MAKE 'a' (1C) -> expect 0 and a 1-cycle pulse
    $display("\n--- Test 1: MAKE 'a' (0x1C) -> expect code 0 ---");
    send_byte(8'h1C);
    repeat (3) @(negedge clock);

    // 2) BREAK 'a' F0,1C -> expect NO pulse
    $display("\n--- Test 2: BREAK 'a' (F0, 1C) -> expect NO output ---");
    send_byte(8'hF0);
    send_byte(8'h1C);
    repeat (3) @(negedge clock);

    // 3) digit '3' (26) -> expect 30 (space=26, so 3=30)
    $display("\n--- Test 3: MAKE '3' (0x26) -> expect code 30 ---");
    send_byte(8'h26);
    repeat (3) @(negedge clock);

    // 4) space (29) -> 26 (NEW MAPPING!)
    $display("\n--- Test 4: MAKE space (0x29) -> expect code 26 ---");
    send_byte(8'h29);
    repeat (3) @(negedge clock);

    // 5) enter (5A) -> 49
    $display("\n--- Test 5: MAKE enter (0x5A) -> expect code 49 ---");
    send_byte(8'h5A);
    repeat (3) @(negedge clock);

    // 6) '-' (4E) -> 38
    $display("\n--- Test 6: MAKE '-' (0x4E) -> expect code 38 ---");
    send_byte(8'h4E);
    repeat (3) @(negedge clock);

    // 7) extended make E0,75 (Up) -> ignore both
    $display("\n--- Test 7: Extended MAKE (E0, 75) -> expect NO output ---");
    send_byte(8'hE0);
    send_byte(8'h75);
    repeat (3) @(negedge clock);

    // 8) extended break E0,F0,75 -> ignore all
    $display("\n--- Test 8: Extended BREAK (E0, F0, 75) -> expect NO output ---");
    send_byte(8'hE0);
    send_byte(8'hF0);
    send_byte(8'h75);
    repeat (4) @(negedge clock);

    // 9) Fast typing test - rapid keys
    $display("\n--- Test 9: Fast typing 'abc' ---");
    send_byte(8'h1C); // a -> 0
    send_byte(8'h32); // b -> 1
    send_byte(8'h21); // c -> 2
    repeat (6) @(negedge clock);

    $display("\n=== TB finished at %0t ns ===", $time);
    $stop;
  end

endmodule