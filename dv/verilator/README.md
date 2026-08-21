# Verilator structural lint

`run.sh` lint-checks the production Xcelium hierarchy with the additional
Ibex primitive packages required by Verilator's package-order rules. This is
not a replacement for Xcelium elaboration or Cadence synthesis. `soc_run.sh`
is an optional full-SoC CPU/MAC attempt; its current run stalls in the CPU
instruction path under Verilator before MAC start and is not treated as a
passing regression.
