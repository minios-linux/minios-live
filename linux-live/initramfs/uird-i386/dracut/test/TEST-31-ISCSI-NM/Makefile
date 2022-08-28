.PHONY: all setup clean run

BASETEST=../TEST-30-ISCSI

all:
	@$(MAKE) NM=1 -s --no-print-directory -C $(BASETEST) all
setup:
	@$(MAKE) NM=1 -s --no-print-directory -C $(BASETEST) setup
clean:
	@$(MAKE) NM=1 -s --no-print-directory -C $(BASETEST) clean
run:
	@$(MAKE) NM=1 -s --no-print-directory -C $(BASETEST) run
