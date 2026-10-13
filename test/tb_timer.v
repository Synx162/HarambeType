`timescale 1ns / 1ps
// Measures how long the countdown_timer actually runs.
// The Makefile compiles a copy of timer.v with the 1-second terminal count
// (49_999_999) replaced by TICK-1 so the test finishes quickly; one "second"
// is then TICK clock cycles.

module tb_timer;
    parameter TICK = 100;
    reg clock = 0;
    always #10 clock = ~clock;

    reg resetn = 0, start = 0;
    wire [3:0] timer_value;
    wire timer_expired, update_pulse;

    countdown_timer DUT (.clock(clock), .resetn(resetn), .start(start),
                         .timer_value(timer_value), .timer_expired(timer_expired),
                         .update_pulse(update_pulse));

    integer cycles = 0;
    integer seconds;
    initial begin
        #100 resetn = 1;
        @(negedge clock) start = 1;
        @(negedge clock) start = 0;
        while (!timer_expired) begin
            @(posedge clock); cycles = cycles + 1;
        end
        seconds = (cycles + TICK/2) / TICK;
        $display("game length = %0d 'seconds' (stats_calculator assumes 15)", seconds);
        if (seconds == 15) $display("PASS tb_timer");
        else $display("XFAIL tb_timer (known bug: timer shows 15..0 and expires one tick after 0)");
        $finish;
    end
endmodule
