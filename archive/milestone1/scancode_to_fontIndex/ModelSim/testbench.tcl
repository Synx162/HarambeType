# testbench.tcl – compile & run the unit test

transcript on
quit -sim

# point to files (edit paths if needed)
set DUT_FILE "scancode_to_fontIndex.v"
set TB_FILE  "tb_scancode_to_fontIndex.v"
set WAVE_DO  "wave.do"

if {![file exists $DUT_FILE]} { puts stderr "ERROR: missing $DUT_FILE"; return }
if {![file exists $TB_FILE]}  { puts stderr "ERROR: missing $TB_FILE";  return }

vlib work
vmap work work

vlog +acc=rn "$DUT_FILE" "$TB_FILE"

vsim -voptargs=+acc work.tb_scancode_to_fontIndex

if {[file exists $WAVE_DO]} {
  do "$WAVE_DO"
} else {
  add wave -hex sim:/tb_scancode_to_fontIndex/*
  add wave -hex sim:/tb_scancode_to_fontIndex/dut/*
}

run -all