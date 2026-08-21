# Yosys structural preflight

`run.sh` performs an open-source hierarchy/proc/check preflight only. It is
not a substitute for Genus and does not provide timing, area, or technology
mapping results. On the current RTL, Yosys stops at the unpacked-array port
declaration in `systolic_array.v`; this is recorded as a tool limitation, not
silently worked around by changing the MAC interface.
