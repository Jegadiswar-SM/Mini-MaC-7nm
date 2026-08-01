# =============================================================================
# innovus_init.tcl — Innovus Init & Floorplan  [ASAP7 7nm]
# Design: Mini-MaC SoC  |  1.122 GHz  |  ASAP7 7nm FinFET
# =============================================================================
#
# Assumes Genus netlist is at: ../syn/out/soc_top_netlist.v
# Run from: cadence_asap7/apr/
# =============================================================================

# -----------------------------------------------------------------------
# 0. PDK Paths — EDIT to match your ASAP7 installation
# -----------------------------------------------------------------------
set PDK_ROOT  "/path/to/asap7"
set LIB_DIR   "$PDK_ROOT/asap7sc7p5t_27/LIB/CCS"
set LEF_DIR   "$PDK_ROOT/asap7sc7p5t_27/LEF"
set GDS_DIR   "$PDK_ROOT/asap7sc7p5t_27/GDS"

# Liberty corners
set LIB_TT  "$LIB_DIR/asap7sc7p5t_28_L_tt_100C_1p8V_conditional_ccs.lib"
set LIB_FF  "$LIB_DIR/asap7sc7p5t_28_L_ff_100C_1p98V_conditional_ccs.lib"
set LIB_SS  "$LIB_DIR/asap7sc7p5t_28_L_ss_100C_1p62V_conditional_ccs.lib"

# -----------------------------------------------------------------------
# 1. MMMC (Multi-Mode Multi-Corner) View Definition
# -----------------------------------------------------------------------
create_library_set -name libs_tt -timing $LIB_TT
create_library_set -name libs_ff -timing $LIB_FF
create_library_set -name libs_ss -timing $LIB_SS

create_constraint_mode -name func \
    -sdc_files ../constraints/soc_top.sdc

create_delay_corner -name tt_corner -library_set libs_tt
create_delay_corner -name ff_corner -library_set libs_ff
create_delay_corner -name ss_corner -library_set libs_ss

create_analysis_view -name setup_view \
    -constraint_mode func \
    -delay_corner ss_corner   ;# worst-case setup

create_analysis_view -name hold_view \
    -constraint_mode func \
    -delay_corner ff_corner   ;# worst-case hold

set_analysis_view -setup {setup_view} -hold {hold_view}

# -----------------------------------------------------------------------
# 2. Initialize Design
# -----------------------------------------------------------------------
set init_design_netlisttype  Verilog
set init_verilog             ../syn/out/soc_top_netlist.v
set init_top_cell            soc_top

set init_lef_file [list \
    $LEF_DIR/asap7_tech.lef       \
    $LEF_DIR/asap7sc7p5t_27_L.lef \
]
# Uncomment when SRAM macro LEF is available:
# lappend init_lef_file /path/to/asap7_sram_2048x32.lef

init_design

# -----------------------------------------------------------------------
# 3. Floorplan
# ASAP7 7nm — small die, tight utilization possible at 7nm
# -----------------------------------------------------------------------
create_floorplan \
    -site   asap7sc7p5t  \
    -utilization  65     \
    -aspectRatio   1.0   \
    -coreSpacingBottom 1.0 \
    -coreSpacingTop    1.0 \
    -coreSpacingLeft   1.0 \
    -coreSpacingRight  1.0

# Place I/O pads (core-only, no padframe — academic flow)
fit_io

# -----------------------------------------------------------------------
# 4. Power Planning
# ASAP7 operates at ~0.7 V (use 0.7V rings)
# -----------------------------------------------------------------------
add_rings \
    -nets        {VDD VSS} \
    -type        core_rings \
    -follow      core \
    -layer       {top M8 bottom M8 left M7 right M7} \
    -width        0.2 \
    -spacing      0.2 \
    -offset       0.5

add_stripes \
    -nets        {VDD VSS} \
    -layer        M7  \
    -direction    vertical \
    -width        0.2 \
    -spacing      0.2 \
    -set_to_set_distance 4.0

route_special -connect {core_pin} -nets {VDD VSS}

# -----------------------------------------------------------------------
# 5. Save
# -----------------------------------------------------------------------
file mkdir out
save_design out/soc_top_init.enc

puts "=== ASAP7 Floorplan DONE — out/soc_top_init.enc ==="
