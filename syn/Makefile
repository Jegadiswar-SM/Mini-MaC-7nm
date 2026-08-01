# =============================================================================
# Makefile — Genus Synthesis  [ASAP7 7nm]
# =============================================================================
GENUS   := genus
SCRIPT  := genus.tcl
LOG     := genus.log

.PHONY: synth reports clean

synth:
	$(GENUS) -batch -files $(SCRIPT) | tee $(LOG)
	@echo ""
	@grep -E "Timing|Area|Errors|Warnings" $(LOG) | tail -20

reports:
	@echo "=== Timing Report ===" && cat out/reports/timing_setup.rpt
	@echo "=== Area Report ===" && cat out/reports/area.rpt
	@echo "=== QoR ===" && cat out/reports/qor.rpt

clean:
	rm -rf out/ genus.log genus.cmd* fv/ genus_work/ .cadence/ *.cmd
