#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
iverilog -g2012 -Wall -Wno-timescale -o /tmp/minimac-sram-banked.vvp \
  rtl/macros/sram_wrapper.v rtl/macros/sram_wrapper_banked_4096x32.v \
  dv/sram/sram_banked_tb.sv
vvp /tmp/minimac-sram-banked.vvp
