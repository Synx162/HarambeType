`timescale 1ns / 1ps

module tb_ps2();
    reg CLOCK_50;
    reg resetn;
    wire PS2_CLK;
    wire PS2_DAT;
    wire [7:0] scancode;
    wire ps2_rec;
    wire [7:0] inputChar;
    wire inputChar_rdy;
    
    // Internal signals to drive PS/2
    reg ps2_clk_drive;
    reg ps2_dat_drive;
    
    // Assign to wires
    assign PS2_CLK = ps2_clk_drive;
    assign PS2_DAT = ps2_dat_drive;
    
    // Instantiate PS/2 receiver
    ps2_receiver PS2_RX (
        .CLOCK_50(CLOCK_50),
        .Resetn(resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .scancode(scancode),
        .ps2_rec(ps2_rec)
    );
    
    // Instantiate scancode decoder
    scancode_to_fontIndex DECODER (
        .clock(CLOCK_50),
        .resetn(resetn),
        .sc(scancode),
        .sc_rdy(ps2_rec),
        .inputChar(inputChar),
        .inputChar_rdy(inputChar_rdy)
    );
    
    // 50MHz clock
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;
    
    // PS/2 clock (much slower, ~10kHz)
    initial ps2_clk_drive = 1;
    always #50000 ps2_clk_drive = ~ps2_clk_drive;
    
    // Test stimulus
    initial begin
        resetn = 0;
        ps2_dat_drive = 1;
        #100;
        resetn = 1;
        #200;
        
        $display("=== TEST 1: Normal key press and release ===");
        // Send scancode 0x1C (letter 'a')
        send_scancode(8'h1C);
        #500000;
        
        // Send BREAK (F0 + 1C)
        send_scancode(8'hF0);
        #500000;
        send_scancode(8'h1C);
        #500000;
        
        $display("=== TEST 2: Another normal key ===");
        // Send scancode 0x32 (letter 'b')
        send_scancode(8'h32);
        #500000;
        send_scancode(8'hF0);
        #500000;
        send_scancode(8'h32);
        #500000;
        
        $display("=== TEST 3: Back-to-back MAKE codes (fast typing) ===");
        // Press 'a' then immediately 'b' (no BREAK in between)
        send_scancode(8'h1C); // a MAKE
        #50000;  // Very short delay
        send_scancode(8'h32); // b MAKE
        #500000;
        
        $display("=== TEST 4: Key auto-repeat (holding key) ===");
        // Press 'c' and hold (repeated MAKE codes)
        send_scancode(8'h21); // c MAKE
        #200000;
        send_scancode(8'h21); // c MAKE (repeat)
        #200000;
        send_scancode(8'h21); // c MAKE (repeat)
        #200000;
        send_scancode(8'h21); // c MAKE (repeat)
        #500000;
        // Release 'c'
        send_scancode(8'hF0);
        #500000;
        send_scancode(8'h21);
        #500000;
        
        $display("=== TEST 5: Overlapping keys (hold 'a', press 'b') ===");
        // Press 'a' (no release)
        send_scancode(8'h1C); // a MAKE
        #300000;
        // Press 'b' while 'a' still held
        send_scancode(8'h32); // b MAKE
        #300000;
        // Release 'a'
        send_scancode(8'hF0);
        #200000;
        send_scancode(8'h1C); // a BREAK
        #300000;
        // Release 'b'
        send_scancode(8'hF0);
        #200000;
        send_scancode(8'h32); // b BREAK
        #500000;
        
        $display("=== TEST 6: Extended key (should be filtered) ===");
        // Press arrow key (E0 + scancode)
        send_scancode(8'hE0); // Extended prefix
        #500000;
        send_scancode(8'h75); // Up arrow
        #500000;
        
        $display("=== TEST 7: Rapid succession (stress test) ===");
        // Type "hello" quickly
        send_scancode(8'h33); // h
        #100000;
        send_scancode(8'h24); // e
        #100000;
        send_scancode(8'h4B); // l
        #100000;
        send_scancode(8'h4B); // l
        #100000;
        send_scancode(8'h44); // o
        #500000;
        
        $display("=== TEST 8: Multiple BREAK codes ===");
        // Press 'a'
        send_scancode(8'h1C);
        #300000;
        // Double BREAK (shouldn't happen but test robustness)
        send_scancode(8'hF0);
        #200000;
        send_scancode(8'h1C);
        #200000;
        send_scancode(8'hF0);
        #200000;
        send_scancode(8'h1C);
        #500000;
        
        $display("=== All tests complete ===");
        $stop;
    end
    
    // Task to send PS/2 scancode (11 bits)
    task send_scancode;
        input [7:0] code;
        integer i;
        reg parity;
        begin
            parity = ^code;
            
            // Start bit
            @(negedge ps2_clk_drive);
            ps2_dat_drive = 0;
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                @(negedge ps2_clk_drive);
                ps2_dat_drive = code[i];
            end
            
            // Parity bit
            @(negedge ps2_clk_drive);
            ps2_dat_drive = ~parity;
            
            // Stop bit
            @(negedge ps2_clk_drive);
            ps2_dat_drive = 1;
            
            @(negedge ps2_clk_drive);
        end
    endtask
endmodule