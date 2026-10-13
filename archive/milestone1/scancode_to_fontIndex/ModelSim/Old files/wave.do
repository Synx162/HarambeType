# wave.do — convenient signals

quietly WaveActivateNextPane {} 0

add wave -divider {TB}
add wave             sim:/tb_scancode_to_fontIndex/clock
add wave             sim:/tb_scancode_to_fontIndex/resetn
add wave -radix hex  sim:/tb_scancode_to_fontIndex/sc
add wave             sim:/tb_scancode_to_fontIndex/sc_rdy
add wave -radix unsigned sim:/tb_scancode_to_fontIndex/inputChar
add wave             sim:/tb_scancode_to_fontIndex/inputChar_rdy

add wave -divider {DUT internals}
add wave -radix unsigned sim:/tb_scancode_to_fontIndex/dut/y
add wave -radix unsigned sim:/tb_scancode_to_fontIndex/dut/Y
add wave -radix hex      sim:/tb_scancode_to_fontIndex/dut/code_num_d
add wave                 sim:/tb_scancode_to_fontIndex/dut/make_cycle

configure wave -namecolwidth 260
configure wave -valuecolwidth 140
configure wave -justifyvalue left
configure wave -timelineunits ns
