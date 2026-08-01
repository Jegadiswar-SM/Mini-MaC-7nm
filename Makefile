# =============================================================================
# Cadence ASAP7 7nm Flow — Mini-MaC SoC
# =============================================================================
#
# Directory layout:
#   cadence_asap7/
#   ├── constraints/soc_top.sdc   (1.122 GHz / 0.891 ns)
#   ├── syn/                      Genus synthesis
#   ├── apr/                      Innovus P&R
#   └── sta/                      Tempus STA
#
# All RTL is referenced relative to this directory: ../../rtl/
# PDK:  ASAP7 7nm FinFET (academic/educational PDK)
# Tool: Genus / Innovus / Tempus (Cadence Genus 21.1+)
# =============================================================================

.PHONY: all sim synth apr sta clean

# Ordered full-flow
all: synth apr sta

sim:
	cd ../../dv/xcelium && $(MAKE) sim

synth:
	cd syn && $(MAKE) synth

apr:
	cd apr && $(MAKE) all

sta:
	cd sta && $(MAKE) sta

clean:
	cd syn && $(MAKE) clean
	cd apr && $(MAKE) clean
	cd sta && $(MAKE) clean
