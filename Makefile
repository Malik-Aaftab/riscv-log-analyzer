# Makefile - riscv-log-analyzer
#
# Run `make help` to list every target.

SHELL := /bin/bash

# ---------- Variables (override on the command line: make DATA_DIR=other/) ----------
SCRIPTS_DIR := scripts
DATA_DIR    := test_data
OUT_DIR     := output

ANALYZE := $(SCRIPTS_DIR)/analyze.sh
REPORT  := $(SCRIPTS_DIR)/generate_report.sh
SETUP   := $(SCRIPTS_DIR)/setup_env.sh

# Every log in test_data/  ->  matching report file in output/  (pattern substitution)
LOGS    := $(sort $(wildcard $(DATA_DIR)/*.log))
REPORTS := $(patsubst $(DATA_DIR)/%.log,$(OUT_DIR)/%.txt,$(LOGS))

# Expected results for `make test`, format  name:exit_code:total:passed:failed:skipped
TESTS := sample_sim:1:10:7:2:1 sample_pass:0:12:12:0:0 sample_fail:1:25:22:2:1

.PHONY: all test report clean help setup

all: ## Run the analyzer on every log in test_data/
	@for log in $(LOGS); do \
	    $(ANALYZE) $$log || [ $$? -eq 1 ] || exit 1; \
	    echo; \
	done

test: ## Analyze each test_data log and verify exit code + counts
	@pass=0; fail=0; \
	for entry in $(TESTS); do \
	    IFS=: read -r name want_rc want_total want_pass want_fail want_skip <<< "$$entry"; \
	    rc=0; out=$$($(ANALYZE) --format csv "$(DATA_DIR)/$$name.log") || rc=$$?; \
	    got=$$(printf '%s\n' "$$out" | tail -n 1 | awk -F, '{ print $$2 ":" $$3 ":" $$4 ":" $$5 }'); \
	    want="$$want_total:$$want_pass:$$want_fail:$$want_skip"; \
	    if [ "$$rc" -eq "$$want_rc" ] && [ "$$got" = "$$want" ]; then \
	        echo "  PASS  $$name (exit $$rc, total:pass:fail:skip = $$got)"; pass=$$((pass + 1)); \
	    else \
	        echo "  FAIL  $$name: expected exit $$want_rc / $$want, got exit $$rc / $$got"; fail=$$((fail + 1)); \
	    fi; \
	done; \
	rc=0; $(ANALYZE) does_not_exist.log > /dev/null 2>&1 || rc=$$?; \
	if [ "$$rc" -eq 2 ]; then \
	    echo "  PASS  missing file is rejected (exit 2)"; pass=$$((pass + 1)); \
	else \
	    echo "  FAIL  missing file: expected exit 2, got $$rc"; fail=$$((fail + 1)); \
	fi; \
	echo "$$pass passed, $$fail failed"; \
	[ "$$fail" -eq 0 ]

report: $(REPORTS) ## Generate per-log reports and a summary in output/
	@$(REPORT) -i $(DATA_DIR) -o $(OUT_DIR)

# Pattern rule: how to build output/<name>.txt from test_data/<name>.log.
# Exit code 1 (= "some tests failed") is a normal outcome, so only 2+ aborts make.
$(OUT_DIR)/%.txt: $(DATA_DIR)/%.log $(ANALYZE) | $(OUT_DIR)
	@$(ANALYZE) $< --output $@ || [ $$? -eq 1 ]
	@echo "  wrote $@"

$(OUT_DIR):
	@mkdir -p $@

clean: ## Remove generated files from output/
	@rm -f $(OUT_DIR)/*.txt $(OUT_DIR)/*.html $(OUT_DIR)/*.csv
	@echo "Removed generated files from $(OUT_DIR)/"

help: ## Print all available targets with descriptions
	@echo "Usage: make <target>"
	@echo
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z_-]+:.*## / { printf "  %-8s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup: ## Check that required tools are installed and prepare the project
	@$(SETUP)

# Debug helper: `make print-LOGS` shows the value of any variable
print-%:
	@echo '$* = $($*)'
