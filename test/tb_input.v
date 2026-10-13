`timescale 1ns / 1ps
// Self-checking test for the keyboard path: ps2_receiver -> scancode_to_fontIndex.
// Drives real PS/2 frames (clock idles high between bytes, data sampled on the
// falling edge) and checks that only make codes for a-z / space produce a
// character, and that break (F0 xx) and extended (E0 xx) sequences are dropped.

module tb_input;
    reg CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;          // 50 MHz

    reg resetn = 0;
    reg ps2_clk_drv = 1, ps2_dat_drv = 1;
    wire PS2_CLK = ps2_clk_drv;
    wire PS2_DAT = ps2_dat_drv;

    wire [7:0] scancode;
    wire       ps2_rec;
    wire [7:0] inputChar;
    wire       inputChar_rdy;

    ps2_receiver RX (.CLOCK_50(CLOCK_50), .Resetn(resetn), .PS2_CLK(PS2_CLK),
                     .PS2_DAT(PS2_DAT), .scancode(scancode), .ps2_rec(ps2_rec));
    scancode_to_fontIndex DEC (.clock(CLOCK_50), .resetn(resetn), .sc(scancode),
                               .sc_rdy(ps2_rec), .inputChar(inputChar),
                               .inputChar_rdy(inputChar_rdy));

    // Record every character the decoder emits
    reg [7:0] got [0:63];
    integer n_got = 0;
    always @(posedge CLOCK_50)
        if (inputChar_rdy) begin
            got[n_got] = inputChar;
            n_got = n_got + 1;
        end

    // One PS/2 frame: start(0), 8 data LSB-first, odd parity, stop(1).
    // ~12.5 kHz keyboard clock (40 us half-period).
    task send_byte(input [7:0] b);
        integer i;
        reg [10:0] frame;
        begin
            frame = {1'b1, ~^b, b, 1'b0};
            for (i = 0; i < 11; i = i + 1) begin
                ps2_dat_drv = frame[i];
                #20000 ps2_clk_drv = 0;      // keyboard pulls clock low; host samples
                #40000 ps2_clk_drv = 1;
                #20000;
            end
            #200000;                          // idle gap between bytes
        end
    endtask

    task press(input [7:0] sc);   begin send_byte(sc); end endtask
    task release_(input [7:0] sc); begin send_byte(8'hF0); send_byte(sc); end endtask
    task tap(input [7:0] sc);     begin press(sc); release_(sc); end endtask

    integer errors = 0;
    task expect_char(input integer idx, input [7:0] val);
        begin
            if (idx >= n_got) begin
                $display("FAIL: expected char #%0d = %0d, but only %0d chars received", idx, val, n_got);
                errors = errors + 1;
            end else if (got[idx] !== val) begin
                $display("FAIL: char #%0d = %0d, expected %0d", idx, got[idx], val);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #200 resetn = 1;
        #1000;

        tap(8'h33);              // h -> 7
        tap(8'h24);              // e -> 4
        tap(8'h4B);              // l -> 11
        tap(8'h29);              // space -> 26
        press(8'hE0); press(8'h75); release_(8'h75);  // up arrow (extended) -> ignored
        tap(8'h16);              // '1' -> not mapped -> ignored
        press(8'h1C); press(8'h1C); release_(8'h1C);  // auto-repeat 'a' -> 0, 0

        #1000000;

        expect_char(0, 8'd7);
        expect_char(1, 8'd4);
        expect_char(2, 8'd11);
        expect_char(3, 8'd26);
        expect_char(4, 8'd0);
        expect_char(5, 8'd0);
        if (n_got != 6) begin
            $display("FAIL: expected 6 characters total, got %0d", n_got);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS tb_input: %0d chars decoded, breaks/extended/unmapped keys filtered", n_got);
        else             $display("FAIL tb_input: %0d error(s)", errors);
        $finish;
    end
endmodule
