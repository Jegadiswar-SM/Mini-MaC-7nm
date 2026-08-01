# =============================================================================
# genus.tcl — Genus RTL-to-Gates Synthesis
# Design:  Mini-MaC SoC (soc_top)
# PDK:     ASAP7 7nm FinFET (academic PDK)
# Target:  1.122 GHz (0.891 ns)
# =============================================================================
#
# Usage: genus -files genus.tcl  (or: make synth)
#
# PDK path variables — edit these to match your ASAP7 installation:
#   ASAP7 PDK is available at:
#   https://github.com/The-OpenROAD-Project/asap7
#   Standard cells: asap7sc7p5t_28_L / AO / SLVT / SRAM variants
# =============================================================================

# -----------------------------------------------------------------------
# 0. Paths — EDIT to match your ASAP7 installation
# -----------------------------------------------------------------------
set PDK_ROOT  "/path/to/asap7"
set LIB_DIR   "$PDK_ROOT/asap7sc7p5t_27/LIB/CCS"
set LEF_DIR   "$PDK_ROOT/asap7sc7p5t_27/LEF"
set RTL_DIR   "../rtl"

# ASAP7 Liberty files — CCS timing models, typical corner
# ASAP7 has 3 drive-strength libraries: RVT (R), SLVT (SL), LVT (L)
# Use L (LVT) for best performance at aggressive clock target
set LIB_TT  "$LIB_DIR/asap7sc7p5t_28_L_tt_100C_1p8V_conditional_ccs.lib"
set LIB_FF  "$LIB_DIR/asap7sc7p5t_28_L_ff_100C_1p98V_conditional_ccs.lib"
set LIB_SS  "$LIB_DIR/asap7sc7p5t_28_L_ss_100C_1p62V_conditional_ccs.lib"

# ASAP7 LEF files
set TECH_LEF "$LEF_DIR/asap7_tech.lef"
set CELL_LEF "$LEF_DIR/asap7sc7p5t_27_L.lef"

# -----------------------------------------------------------------------
# 1. Tool Setup
# -----------------------------------------------------------------------
set_db / .init_lib_search_path  $LIB_DIR
set_db / .init_hdl_search_path  $RTL_DIR

# Synthesis effort: medium for initial runs, high for tapeout
set_db / .syn_generic_effort    medium
set_db / .syn_map_effort        medium
set_db / .syn_opt_effort        medium

# Enable multi-threading (adjust to available CPU cores)
set_db / .max_cpus_per_server   4

# -----------------------------------------------------------------------
# 2. Read Libraries
# -----------------------------------------------------------------------
read_libs $LIB_TT

# ASAP7 SRAM macro Liberty — from ASAP7 memory compiler (placeholder)
# Uncomment and set path when using real SRAM hard macro:
# read_libs /path/to/asap7_sram_2048x32_tt.lib

# Physical LEF for P&R awareness
read_physical -lef [list $TECH_LEF $CELL_LEF]
# read_physical -lef /path/to/asap7_sram_2048x32.lef

# -----------------------------------------------------------------------
# 3. Read RTL
# -----------------------------------------------------------------------

# --- Ibex SystemVerilog (package must compile first) ---
read_hdl -sv $RTL_DIR/core/ibex/rtl/ibex_pkg.sv

foreach ibex_file {
    ibex_pmp
    ibex_alu
    ibex_branch_predict
    ibex_compressed_decoder
    ibex_csr
    ibex_counter
    ibex_cs_registers
    ibex_decoder
    ibex_dummy_instr
    ibex_ex_block
    ibex_fetch_fifo
    ibex_id_stage
    ibex_if_stage
    ibex_load_store_unit
    ibex_multdiv_slow
    ibex_multdiv_fast
    ibex_prefetch_buffer
    ibex_register_file_ff
    ibex_wb_stage
    ibex_core
    ibex_top
} {
    read_hdl -sv $RTL_DIR/core/ibex/rtl/${ibex_file}.sv
}

# --- Project Verilog RTL ---
# SYNTHESIS define: activates `ifdef SYNTHESIS path in mac_top (no column-shift)
# and hides sram_wrapper behavioral body (black-box inference)
read_hdl -define SYNTHESIS [list \
    $RTL_DIR/macros/sram_wrapper.v           \
    $RTL_DIR/bus/apb_bus.v                   \
    $RTL_DIR/bus/obi_to_apb.v               \
    $RTL_DIR/accel/pe.v                      \
    $RTL_DIR/accel/systolic_array.v          \
    $RTL_DIR/accel/mac_cfg_regs.v            \
    $RTL_DIR/accel/axi_stream_dma.v          \
    $RTL_DIR/accel/mac_core_axi.v            \
    $RTL_DIR/accel/mac_multicore.v          \
    $RTL_DIR/core/boot_rom.v                \
    $RTL_DIR/core/dma_regs.v               \
    $RTL_DIR/core/dma_master.v             \
    $RTL_DIR/core/mem_subsystem.v          \
    $RTL_DIR/core/telemetry.v              \
    $RTL_DIR/soc_top.v                     \
]

# -----------------------------------------------------------------------
# 4. Elaborate
# -----------------------------------------------------------------------
elaborate soc_top

check_design -unresolved

# -----------------------------------------------------------------------
# 5. Constraints
# -----------------------------------------------------------------------
read_sdc ../constraints/soc_top.sdc

# -----------------------------------------------------------------------
# 6. Synthesis
# -----------------------------------------------------------------------
syn_generic
syn_map
syn_opt

# -----------------------------------------------------------------------
# 7. Output Netlist & SDC
# -----------------------------------------------------------------------
file mkdir out
write_hdl  > out/soc_top_netlist.v
write_sdc  > out/soc_top_syn.sdc

# Verilog netlist for LEC golden reference
write_hdl -generic > out/soc_top_generic.v

# -----------------------------------------------------------------------
# 8. Reports
# -----------------------------------------------------------------------
file mkdir out/reports

# Timing summary — worst path per path group
report_timing -max_paths 20  -path_type full \
    > out/reports/timing_setup.rpt

# Area breakdown by instance
report_area  -hier \
    > out/reports/area.rpt

# Power estimate (pre-layout switching activity)
report_power -hier \
    > out/reports/power.rpt

# Gate count
report_gates \
    > out/reports/gates.rpt

# Constraint violations
report_constraint -all_violators \
    > out/reports/violations.rpt

# QoR summary
report_qor \
    > out/reports/qor.rpt

puts "============================================"
puts "  ASAP7 Genus Synthesis COMPLETE"
puts "  Netlist: out/soc_top_netlist.v"
puts "  Reports: out/reports/"
puts "============================================"
