module stats_calculator (clock, resetn, start_new_test, timer_expired, char_errors, total_chars, wpm_bcd, accuracy_bcd);
    input wire clock;
    input wire resetn;
    input wire start_new_test;
    input wire timer_expired;
    input wire [15:0] char_errors;
    input wire [15:0] total_chars;
    
    // WPM: max realistic 400, needs 3 BCD digits (0-999)
    output reg [11:0] wpm_bcd;        // 3 BCD digits: [11:8]=hundreds, [7:4]=tens, [3:0]=ones
    
    // Accuracy: max 100%, needs 3 BCD digits (0-100)
    output reg [11:0] accuracy_bcd;   // 3 BCD digits: [11:8]=hundreds, [7:4]=tens, [3:0]=ones
    
    // Internal calculations (binary)
    reg [15:0] correct_chars;         // max ~500 chars in 15 sec
    reg [8:0] wpm_temp;               // max 400, needs 9 bits (up to 511)
    reg [6:0] accuracy_temp;          // max 100, needs 7 bits (up to 127)
    
    // Calculate correct characters
    always @(*) begin
        if (total_chars >= char_errors)
            correct_chars = total_chars - char_errors;
        else
            correct_chars = 16'd0;
    end
    
    // Calculate WPM = (correct_chars / 5) * (60 / time)
    // Since timer counts down from 15 seconds:
    // WPM = (correct_chars / 5) * 4  (because 60/15 = 4)
    always @(*) begin
        wpm_temp = (correct_chars * 4) / 5;
    end
    
    // Calculate accuracy = (correct_chars / total_chars) * 100
    always @(*) begin
        if (total_chars > 0)
            accuracy_temp = (correct_chars * 100) / total_chars;
        else
            accuracy_temp = 7'd0;
    end
    
    // Convert to BCD and register on timer_expired
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            wpm_bcd <= 12'd0;
            accuracy_bcd <= 12'd0;
        end else if (start_new_test) begin
            wpm_bcd <= 12'd0;
            accuracy_bcd <= 12'd0;
        end else if (timer_expired) begin
            // Convert WPM to BCD (3 digits: hundreds, tens, ones)
            wpm_bcd[11:8] <= (wpm_temp / 100) % 10;
            wpm_bcd[7:4]  <= (wpm_temp / 10) % 10;
            wpm_bcd[3:0]  <= wpm_temp % 10;
            
            // Convert accuracy to BCD (3 digits: 0-100)
            accuracy_bcd[11:8] <= (accuracy_temp / 100) % 10;
            accuracy_bcd[7:4]  <= (accuracy_temp / 10) % 10;
            accuracy_bcd[3:0]  <= accuracy_temp % 10;
        end
    end
endmodule