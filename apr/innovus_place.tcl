# =============================================================================
# innovus_place.tcl — Placement  [ASAP7 7nm]
# =============================================================================
restore_design out/soc_top_init.enc

# Standard cell placement
place_design

# Pre-CTS timing optimization
# Fixes setup violations, buffers long wires before clock tree
optDesign -preCTS
optDesign -preCTS -hold

file mkdir out/reports
report_timing -max_paths 10 > out/reports/preCTS_timing.rpt

save_design out/soc_top_placed.enc
puts "=== ASAP7 Placement DONE ==="
