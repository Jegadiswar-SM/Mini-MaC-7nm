# Xcelium smoke baseline

Run the baseline from any directory with:

```sh
dv/xcelium/run.sh
```

The script compiles and elaborates `soc_top_tb`, then runs a reset-and-clock smoke
simulation for 100 cycles after reset release. It creates a SHM waveform database
at `dv/xcelium/waves.shm` and a log at `dv/xcelium/xrun.log`.

A passing run proves that the listed synthesizable SoC RTL, its required Ibex
packages and generic primitives, and the behavioral `sram_wrapper.v` compile,
elaborate, reset, and terminate cleanly in Xcelium 22.09-s003. It does not prove
CPU software execution, bus transactions, DMA behavior, MAC computation, SRAM
contents, or any other functional correctness.

## Baseline assumptions

- `mem_subsystem` is instantiated with `NUM_MAC_MASTERS=4`, matching its fixed
  four-slot MAC arbitration implementation. `soc_top` does not yet connect MAC
  memory request ports, so all four slots are intentionally tied inactive.
- The Ibex cache configuration inputs are 12 bits and are tied to `12'h000`.
- The behavioral SRAM wrapper remains the simulation model; ASAP7 SRAM physical
  integration is outside this baseline.

## Known warning

Xcelium reports two `BNDASW` warnings at `ibex_top.sv:1208`. In Ibex's data-side
pending-access tracker, each generated `always_comb` block contains a guarded
reference to `pending_dside_accesses_q[i + 1]`. For the final generated index the
runtime condition `i != MaxOutstandingDSideAccesses - 1` is false, so that
out-of-range reference cannot execute. Xcelium nevertheless includes the textual
reference in the block sensitivity analysis and warns. This is a vendor-coding/tool
compatibility warning, not an elaboration or runtime correctness failure; it is not
suppressed or modified here.
