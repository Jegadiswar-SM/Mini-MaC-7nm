# =============================================================================
# Makefile — Innovus P&R  [ASAP7 7nm]
# =============================================================================
INNOVUS := innovus
FLAGS   := -nowin -batch

.PHONY: all init place cts route signoff clean

all: init place cts route signoff

init:
	$(INNOVUS) $(FLAGS) -files innovus_init.tcl     | tee init.log

place:
	$(INNOVUS) $(FLAGS) -files innovus_place.tcl    | tee place.log

cts:
	$(INNOVUS) $(FLAGS) -files innovus_cts.tcl      | tee cts.log

route:
	$(INNOVUS) $(FLAGS) -files innovus_route.tcl    | tee route.log

signoff:
	$(INNOVUS) $(FLAGS) -files innovus_signoff.tcl  | tee signoff.log
	@echo ""
	@echo "=== DRC Summary ==="
	@grep -c "VIOLATION" out/reports/drc.rpt || echo "DRC clean"

clean:
	rm -rf out/ *.log *.cmd* *.enc *.enc.dat/ innovus.* .cadence/
