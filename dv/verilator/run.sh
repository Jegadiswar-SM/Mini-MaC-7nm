#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
mkdir -p /tmp/minimac-verilator
verilator --lint-only --language 1800-2012 \
  -Wall -Wno-fatal \
  -Irtl/inc -Irtl/core/ibex/vendor/lowrisc_ip/ip/prim/rtl \
  -f dv/verilator/lint.f \
  --top-module soc_top 2>&1 | tee /tmp/minimac-verilator/lint.log
