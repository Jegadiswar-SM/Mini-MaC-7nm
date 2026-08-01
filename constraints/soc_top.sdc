# =============================================================================
# soc_top.sdc — Mini-MaC SoC Timing Constraints
# PDK:    ASAP7 7nm FinFET (academic PDK)
# Target: 1.122 GHz  (0.891 ns period)
# =============================================================================

# -----------------------------------------------------------------------------
# Primary Clock
# -----------------------------------------------------------------------------
set PERIOD 0.891

create_clock -name clk \
             -period $PERIOD \
             [get_ports clk]

# Clock quality: uncertainty = jitter + skew budget
set_clock_uncertainty  0.030 [get_clocks clk]
# Max slew at clock pins (ASAP7 7nm — fast edge rates)
set_clock_transition   0.020 [get_clocks clk]
# Insertion delay budget
set_clock_latency      0.050 [get_clocks clk]

# -----------------------------------------------------------------------------
# Input / Output Delays  (20% of period each side)
# -----------------------------------------------------------------------------
set_input_delay  -clock clk  0.150 [all_inputs]
set_output_delay -clock clk  0.150 [all_outputs]

# Reset pin is asynchronous — exclude from timing analysis
set_false_path -from [get_ports rst_n]

# -----------------------------------------------------------------------------
# Drive strength & Load assumptions
# (ASAP7 7nm — BUF_X2 drive, INV_X1 load equivalent)
# Adjust cell names to match your ASAP7 library variant
# -----------------------------------------------------------------------------
# set_driving_cell -lib_cell BUF_X2  [all_inputs]
# set_load [load_of BUF_X2/A]        [all_outputs]

# -----------------------------------------------------------------------------
# Physical Constraints
# -----------------------------------------------------------------------------
# Max fanout per cell output (ASAP7 7nm FinFET — low fanout for speed)
set_max_fanout   16 [current_design]
# Max transition time — ASAP7 7nm target (very tight)
set_max_transition 0.050 [current_design]

# -----------------------------------------------------------------------------
# Multi-Cycle Path — Systolic Array PE Multiplier Pipeline
# The PE multiplier is a 3-stage pipeline; the multiply accumulate register
# sees data settle after 2 clock cycles from the array feed state.
# -----------------------------------------------------------------------------
set_multicycle_path 2 -setup \
    -from [get_pins -hierarchical -filter "NAME=~*u_array*pe*mul_reg*"] \
    -to   [get_pins -hierarchical -filter "NAME=~*u_array*pe*mul_reg*"]

# Companion hold multi-cycle (hold is always N-1 for N-cycle setup MCP)
set_multicycle_path 1 -hold \
    -from [get_pins -hierarchical -filter "NAME=~*u_array*pe*mul_reg*"] \
    -to   [get_pins -hierarchical -filter "NAME=~*u_array*pe*mul_reg*"]

# -----------------------------------------------------------------------------
# SRAM Black-Box — Do not optimize through the macro
# Genus/Innovus treat sram_wrapper as a boundary cell
# -----------------------------------------------------------------------------
set_dont_touch [get_cells -hierarchical -filter "REF_NAME==sram_wrapper"]

# -----------------------------------------------------------------------------
# Case Analysis — Functional mode (DFT not yet inserted)
# -----------------------------------------------------------------------------
# set_case_analysis 0 [get_ports scan_en]   ;# uncomment when DFT is added

# =============================================================================
# End of constraints
# =============================================================================
