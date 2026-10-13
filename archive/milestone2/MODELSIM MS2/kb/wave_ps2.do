# Wave configuration for PS/2 testing

# Add clocks
add wave -divider "Clocks"
add wave -color Yellow sim:/tb_ps2/CLOCK_50
add wave -color Yellow sim:/tb_ps2/PS2_CLK
add wave sim:/tb_ps2/resetn

# Add PS/2 signals
add wave -divider "PS/2 Interface"
add wave sim:/tb_ps2/PS2_DAT
add wave -radix hex sim:/tb_ps2/scancode
add wave sim:/tb_ps2/ps2_rec

# Add decoder outputs
add wave -divider "Decoder Outputs"
add wave -radix unsigned sim:/tb_ps2/inputChar
add wave sim:/tb_ps2/inputChar_rdy

# Add internal PS/2 receiver signals
add wave -divider "PS/2 Receiver Internals"
add wave -radix hex sim:/tb_ps2/PS2_RX/Serial
add wave -radix unsigned sim:/tb_ps2/PS2_RX/Packet

# Add decoder internal state
add wave -divider "Decoder Internals"
add wave sim:/tb_ps2/DECODER/saw_F0
add wave sim:/tb_ps2/DECODER/saw_E0

# Configure wave window
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -timelineunits ns

# Zoom to fit
wave zoom full
