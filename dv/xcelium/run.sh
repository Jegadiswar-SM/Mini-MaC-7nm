#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

work_dir="dv/xcelium/xcelium.d"
log_file="dv/xcelium/xrun.log"

rm -rf "$work_dir"

echo "== Build deterministic CPU DMA firmware =="
python3 dv/xcelium/build_firmware.py

echo "== Xcelium compile/elaborate =="
xrun -64bit -sv -timescale 1ns/1ps \
    -f dv/xcelium/filelist.f \
    -top soc_top_tb \
    -access +rwc \
    -xmlibdirname "$work_dir" \
    -l "$log_file" \
    -elaborate

echo "== Xcelium simulation =="
xrun -64bit -xmlibdirname "$work_dir" -R -l "$log_file" \
    +firmware=dv/xcelium/firmware.hex

echo "== Xcelium smoke flow passed =="
