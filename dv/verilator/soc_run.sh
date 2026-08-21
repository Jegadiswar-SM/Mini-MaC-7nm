#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
mkdir -p /tmp/minimac-verilator
verilator --binary --timing --language 1800-2012 \
  -Wno-fatal -Irtl/inc -Irtl/core/ibex/vendor/lowrisc_ip/ip/prim/rtl \
  -f dv/verilator/lint.f dv/verilator/soc_tb.sv \
  --top-module soc_verilator_tb -o /tmp/minimac-verilator/soc_sim \
  2>&1 | tee /tmp/minimac-verilator/build.log
/tmp/minimac-verilator/soc_sim
