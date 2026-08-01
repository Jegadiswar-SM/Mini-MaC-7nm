# =============================================================================
# Makefile — Tempus STA  [ASAP7 7nm]
# =============================================================================
TEMPUS := tempus
SCRIPT := tempus.tcl
LOG    := tempus.log

.PHONY: sta clean

sta:
	$(TEMPUS) -batch -files $(SCRIPT) | tee $(LOG)
	@echo ""
	@echo "=== Violation Summary ==="
	@grep -E "^(WNS|TNS|SETUP|HOLD|MET|VIOLATED)" $(LOG) | head -20 || true

clean:
	rm -rf out/ $(LOG) tempus.cmd* .cadence/
