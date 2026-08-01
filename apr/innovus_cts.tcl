# =============================================================================
# innovus_cts.tcl — Clock Tree Synthesis  [ASAP7 7nm]
# =============================================================================
restore_design out/soc_top_placed.enc

# CCOpt-based clock tree synthesis (Concurrent Clock and Data Optimization)
# CCOpt is recommended for ASAP7 7nm due to aggressive timing targets
create_clock_tree_spec \
    -output out/clock_tree.ctstch \
    -exceptions {                   \
        -no_boundary_cell           \
    }

set_ccopt_property buffer_cells   [get_lib_cells *BUF*]
set_ccopt_property inverter_cells [get_lib_cells *INV*]

ccopt_design

# Post-CTS optimization — fix setup and hold violations after CTS
optDesign -postCTS
optDesign -postCTS -hold

file mkdir out/reports
report_timing       -max_paths 10    > out/reports/postCTS_timing.rpt
report_clock_timing -type summary    > out/reports/clock_summary.rpt

save_design out/soc_top_cts.enc
puts "=== ASAP7 CTS DONE ==="
