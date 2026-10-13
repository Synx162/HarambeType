# PS/2 Input Test - Compile and Run Script

# Create work library
vlib work

# Compile all source files
vlog ps2_receiver.v
vlog scancode_to_fontIndex.v
vlog tb_ps2.v

# Start simulation
vsim work.tb_ps2

# Load wave.do if it exists
do wave_ps2.do

# Run simulation (extended for edge cases)
run 20ms
