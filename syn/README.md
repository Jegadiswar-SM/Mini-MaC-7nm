# Cadence synthesis handoff

The entry point is `genus.tcl` with top `soc_top`. `filelist.f` records the
project RTL list; the Genus script additionally reads the Ibex SystemVerilog
sources in package/dependency order.

No Cadence tool is required or run on the personal PC. The behavioral
`sram_wrapper` remains a simulation model and is intended to be replaced by a
foundry SRAM macro view during the C2S flow.

ASAP7 naming is intentionally split according to the checked-in technology
guide: Liberty files use the `_28` file names, while the available physical
LEF/GDS names use `_27`. The PDK root and these variant paths must be checked
against the lab installation before execution.
