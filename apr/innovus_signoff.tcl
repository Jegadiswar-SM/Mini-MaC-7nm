# =============================================================================
# innovus_signoff.tcl — Signoff Checks & Outputs  [ASAP7 7nm]
# =============================================================================
restore_design out/soc_top_routed.enc

file mkdir out/reports

# -----------------------------------------------------------------------
# 1. Physical Verification
# -----------------------------------------------------------------------
verify_drc          -report out/reports/drc.rpt
verify_connectivity -report out/reports/connectivity.rpt

# -----------------------------------------------------------------------
# 2. RC Extraction for STA
# -----------------------------------------------------------------------
extractRC \
    -outfile out/soc_top.spef \
    -corners {typical}

# -----------------------------------------------------------------------
# 3. Output Netlist (post-route, for Tempus)
# -----------------------------------------------------------------------
write_netlist out/soc_top_postroute.v \
    -top_module_first \
    -exclude_leaf_cells

# -----------------------------------------------------------------------
# 4. GDS Stream Out
# -----------------------------------------------------------------------
# Merge with ASAP7 standard cell GDS
# set GDS_DIR "/path/to/asap7/GDS"
# write_stream out/soc_top.gds \
#     -merge [list $GDS_DIR/asap7sc7p5t_27_L.gds] \
#     -units 1000 \
#     -mode ALL

# -----------------------------------------------------------------------
# 5. Final Reports
# -----------------------------------------------------------------------
report_timing  -max_paths 20 -path_type full > out/reports/final_timing.rpt
report_power                                 > out/reports/final_power.rpt
report_area                                  > out/reports/final_area.rpt
report_clock_timing -type summary            > out/reports/final_clk.rpt
report_constraint  -all_violators            > out/reports/final_violations.rpt

puts "============================================"
puts "  ASAP7 Innovus Signoff COMPLETE"
puts "  SPEF:    out/soc_top.spef"
puts "  Netlist: out/soc_top_postroute.v"
puts "  DRC:     out/reports/drc.rpt"
puts "============================================"
