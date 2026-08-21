# Mini-MaC C2S handoff

## Current status

The personal-PC preparation includes production-MAC Icarus verification,
independent Python modeling, activation and weight sensitivity tests, and a
4096x32 banked behavioral SRAM test. Cadence results are intentionally absent.
The current revision is **NON-CADENCE PREPARATION INCOMPLETE** because the
full-SoC Verilator CPU run stalls in instruction response, Yosys cannot parse
the production unpacked-array syntax, and authoritative Xcelium is unavailable
on this PC.

## Required software and tools

- Cadence Xcelium, Genus, Innovus, Tempus, and Siemens Calibre
- Lab-approved ASAP7 PDK and SRAM macro collateral
- GCC/binutils or the repository dependency-free firmware generator

## Technology expectations

Set `PDK_ROOT` in the Cadence scripts to the lab ASAP7 installation. The
checked-in guide identifies the standard-cell family as `asap7sc7p5t`. The
scripts use `_28` Liberty filenames and `_27` physical LEF/GDS filenames
because those are the names documented by `tech/README.md`; verify the exact
installed directory layout before running.

The SRAM wrapper is behavioral. Provide approved logical SRAM macro views, or
preserve the black-box strategy and complete macro integration in the lab.

## Xcelium entry point

From repository root:

```sh
python3 dv/xcelium/build_firmware.py
bash dv/xcelium/run.sh
```

The flow elaborates `soc_top_tb` from `dv/xcelium/filelist.f` and supplies
`+firmware=dv/xcelium/firmware.hex`. Confirm the complete regression, including
`CPU_MAC_SOFTWARE`, on C2S. The personal PC has no `xrun` executable.

## Cadence entry points

```sh
cd syn && make synth
cd ../apr && make all
cd ../sta && make
```

Innovus consumes the Genus netlist from `syn/out/`; Tempus consumes the routed
netlist/SPEF from `apr/out/`. Calibre requires the lab-approved rule deck,
layout stream, extracted netlist, and approved SRAM collateral.

## Expected outputs

- `dv/xcelium/xrun.log` and `dv/xcelium/waves.shm/`
- `syn/out/soc_top_netlist.v` and `syn/out/reports/`
- `apr/out/` implementation database, post-route netlist, SPEF, GDS, and reports
- `sta/out/` timing, clock, power, and violation reports
- Calibre DRC/LVS/PEX reports under the lab signoff flow

## Known warnings and limitations

- Ibex vendor RTL has known empty-pin/tool-compatibility warnings; it was not
  modified.
- Verilator reports intentional unused outputs and empty connections; no
  unresolved multiple-driver or width-correctness errors remain after local
  fixes.
- Yosys cannot parse the Ibex primitive package syntax and cannot replace
  Genus. A MAC-only Yosys attempt is retained as a documented limitation.
- A full-SoC Verilator attempt compiles but currently stalls in the CPU
  instruction-response path (`instr_pending=1`, no progress past PC `0xD4`);
  it is not a passing CPU/MAC regression and Xcelium remains authoritative.
- No physical SRAM integration, timing, area, congestion, DRC, LVS, PEX, or
  GDS result is available on the personal PC.
- MAC `DIM.K` is stored by the APB register file but is not consumed by the
  current `mac_core_axi` state machine; `BIAS_EN` is a documented stub. The
  local regression therefore verifies the actual 4x4 implementation, not an
  inferred general matrix-multiply contract.

## Remaining C2S-only validation

1. Run the complete Xcelium regression and inspect `CPU_MAC_SOFTWARE` numerical
   result and DMA ownership under the full SoC.
2. Resolve lab-specific ASAP7 Liberty/LEF/GDS and SRAM macro paths.
3. Run Genus and inspect unresolved references, synthesis warnings, area,
   timing, and macro black-box handling.
4. Run Innovus init/place/CTS/route/signoff.
5. Run Tempus with post-route SPEF and the checked-in SDC.
6. Run Calibre DRC/LVS/PEX with lab decks and approved SRAM views.
7. Review final GDSII and signoff reports.
