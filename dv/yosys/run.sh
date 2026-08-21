#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
mapfile -t files < <(sed -e '/^[[:space:]]*$/d' dv/yosys/mac.f)
file_args="${files[*]}"
mkdir -p /tmp/minimac-yosys
yosys -p "read_verilog -sv -D SYNTHESIS ${file_args}; hierarchy -check -top mac_multicore; proc; check" \
  2>&1 | tee /tmp/minimac-yosys/preflight.log
