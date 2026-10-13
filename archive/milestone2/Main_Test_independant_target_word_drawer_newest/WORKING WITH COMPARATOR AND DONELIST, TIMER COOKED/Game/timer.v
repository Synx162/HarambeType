module countdown_timer(clock, resetn, start, timer_value, timer_expired, update_pulse);
    input wire clock;
    input wire resetn;
    input wire start;              // Pulse KEY[2] to start
    output reg [3:0] timer_value;  // 0-15
    output reg timer_expired;      // 1 when reaches 0
    output reg update_pulse;       // Pulses every second
    
    reg [25:0] counter;
    reg counting;
    
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            counter <= 26'd0;
            timer_value <= 4'd15;
            timer_expired <= 1'b0;
            counting <= 1'b0;
            update_pulse <= 1'b0;
        end else begin
            update_pulse <= 1'b0;
            
            if (start && !counting) begin
                counting <= 1'b1;
                timer_value <= 4'd15;
                timer_expired <= 1'b0;
                counter <= 26'd0;
            end
            
            if (counting) begin
                if (counter == 26'd49_999_999) begin
                    counter <= 26'd0;
                    update_pulse <= 1'b1;
                    
                    if (timer_value == 4'd0) begin
                        timer_expired <= 1'b1;
                        counting <= 1'b0;
                    end else begin
                        timer_value <= timer_value - 4'd1;
                    end
                end else begin
                    counter <= counter + 26'd1;
                end
            end
        end
    end
endmodule