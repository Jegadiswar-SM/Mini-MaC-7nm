#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
python3 dv/mac/golden_model.py
iverilog -g2012 -Wall -Wno-timescale \
  -o /tmp/minimac-mac-functional.vvp \
  rtl/macros/sram_wrapper.v rtl/accel/pe.v rtl/accel/systolic_array.v \
  rtl/accel/mac_core_axi.v dv/mac/mac_tb.sv
vvp /tmp/minimac-mac-functional.vvp
iverilog -g2012 -Wall -Wno-timescale \
  -o /tmp/minimac-mac-result-path.vvp \
  rtl/macros/sram_wrapper.v rtl/accel/pe.v rtl/accel/systolic_array.v \
  rtl/accel/mac_core_axi.v rtl/accel/axi_stream_dma.v dv/mac/mac_dma_tb.sv
vvp /tmp/minimac-mac-result-path.vvp
