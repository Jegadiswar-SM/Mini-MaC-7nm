# ASAP7 7nm PDK — Technology Files Guide

## Overview

This directory contains pointers to the ASAP7 7nm FinFET PDK files required
for the Cadence Genus / Innovus / Tempus flow.

**ASAP7** is an academic 7nm FinFET PDK developed by the University of Texas at
Austin and ARM Ltd. It is freely available for research/academic use.

## PDK Source

```
https://github.com/The-OpenROAD-Project/asap7
```

Or via OpenROAD-flow-scripts which bundles ASAP7 automatically.

## Required Files

### Liberty (Timing) — place in your PDK install path

| Corner | Voltage | Temp | Filename |
|--------|---------|------|----------|
| TT (typical-typical) | 1.80 V | 100°C | `asap7sc7p5t_28_L_tt_100C_1p8V_conditional_ccs.lib` |
| FF (fast-fast)       | 1.98 V | 100°C | `asap7sc7p5t_28_L_ff_100C_1p98V_conditional_ccs.lib` |
| SS (slow-slow)       | 1.62 V | 100°C | `asap7sc7p5t_28_L_ss_100C_1p62V_conditional_ccs.lib` |

The `28_L` refers to the 28-track LVT (Low-Voltage Threshold) cell variant,
which gives the best performance for our 1.122 GHz target.

### LEF (Physical Abstract)

| File | Purpose |
|------|---------|
| `asap7_tech.lef` | Metal stack, via rules, DRC rules |
| `asap7sc7p5t_27_L.lef` | Cell abstracts for placement/routing |

### GDS (for Stream-Out)

| File | Purpose |
|------|---------|
| `asap7sc7p5t_27_L.gds` | Full-chip GDS merge at signoff |

### SRAM Macro

ASAP7 does not include a production SRAM compiler. Options:
1. Use **OpenRAM** with ASAP7 PDK: https://github.com/VLSIDA/OpenRAM
2. Use **Skywater 130nm SRAM** as a behavioral stand-in (mixed-node flow)
3. Keep `sram_wrapper` as a black-box and focus on logic synthesis/P&R metrics

## Script Configuration

In `syn/genus.tcl`, `apr/innovus_init.tcl`, and `sta/tempus.tcl`, set:
```tcl
set PDK_ROOT "/path/to/asap7"
```

All other paths are derived from `PDK_ROOT`.

## Key Parameters (ASAP7 7nm)

| Parameter | Value |
|-----------|-------|
| Technology node | 7nm FinFET |
| Supply voltage | 0.7 V (nominal) |
| Clock target | 1.122 GHz (0.891 ns) |
| Metal layers | M1–M9 (local interconnect + global) |
| Minimum pitch (M1) | ~27 nm |
| Standard cell height | 7.5 track (asap7sc7p5t) |
