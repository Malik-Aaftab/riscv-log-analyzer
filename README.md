# riscv-log-analyzer

A shell-based tool that analyzes RISC-V simulation log files, extracts pass/fail/skip
results and timing information, and produces text, CSV or HTML summary reports.

Built for the **MEDS Lab Module 1 Grand Assignment** (Linux shell, Bash scripting,
Git workflow and Makefiles), UET Lahore - Summer Training Programme 2026.

## Features

- Counts total / PASS / FAIL / SKIP tests and computes the pass rate
- Lists every failing test by name
- Per-test execution time plus min / max / average statistics
- Text report (default) or one-row CSV summary (`--format csv`)
- Exit code `0` when all tests pass, `1` when any test fails, `2` on usage errors
- `--compare old.log` lists **regressions** (PASS -> FAIL) and fixes (FAIL -> PASS)
- `--color` for green PASS / red FAIL output
- `generate_report.sh` builds a text and an HTML summary for a whole directory of logs

## Requirements

Ubuntu 22.04+ (native or WSL2) with `bash` 4+, `grep`, `sed`, `awk`, `sort`, `tr`,
`date`, `mktemp` and `make`. All of these ship with a default Ubuntu install
(`sudo apt install build-essential` covers `make`).

## Installation

```bash
git clone git@github.com:<your-username>/riscv-log-analyzer.git
cd riscv-log-analyzer
make setup      # verifies the tools, makes scripts executable, creates output/
make test       # optional: run the built-in checks
```

## Usage

```bash
# Basic text report
./scripts/analyze.sh test_data/sample_fail.log

# CSV summary, written to a file
./scripts/analyze.sh test_data/sample_fail.log --format csv --output output/fail.csv

# Per-test details on top of the report, with colours
./scripts/analyze.sh test_data/sample_sim.log --verbose --color

# Which tests regressed compared with an older run?
./scripts/analyze.sh new_run.log --compare old_run.log

# Use the exit code in scripts / CI
if ./scripts/analyze.sh run.log --format csv > /dev/null; then echo "all good"; fi

# Summary report for a directory of logs (text + HTML in output/)
./scripts/generate_report.sh -i test_data -o output
```

See [docs/USAGE.md](docs/USAGE.md) for the complete command reference.

## Sample output

`./scripts/analyze.sh test_data/sample_fail.log`

```text
=== RISC-V Simulation Log Analysis ===
Log file: test_data/sample_fail.log
Analysis date: 2026-09-29 07:23:42

--- Results Summary ---
Total tests: 25
Passed:      22 (88.0%)
Failed:       2 ( 8.0%)
Skipped:      1 ( 4.0%)

--- Failed Tests ---
  1. rv32i-sll
  2. rv32i-beq

--- Timing Statistics ---
Min time:  0.42s (rv32i-nop)
Max time:  2.31s (rv32i-mul)
Avg time:  0.87s

--- Verdict: FAIL ---
Exit code: 1
```

`./scripts/analyze.sh test_data/sample_fail.log --format csv`

```csv
log_file,total,passed,failed,skipped,pass_rate,min_time,max_time,avg_time,failed_tests
test_data/sample_fail.log,25,22,2,1,88.0,0.42,2.31,0.87,rv32i-sll;rv32i-beq
```

## Make targets

| Target        | What it does                                              |
|---------------|-----------------------------------------------------------|
| `make all`    | Run the analyzer on every log in `test_data/`             |
| `make test`   | Analyze each test log and verify exit code and counts     |
| `make report` | Write per-log reports and `summary.txt/.html` to `output/`|
| `make clean`  | Remove generated files from `output/`                     |
| `make help`   | List all targets with descriptions                        |
| `make setup`  | Check required tools and prepare the project              |

## Project structure

```text
riscv-log-analyzer/
├── README.md
├── Makefile
├── .gitignore
├── scripts/
│   ├── analyze.sh            # main analysis script
│   ├── setup_env.sh          # environment check
│   └── generate_report.sh    # text + HTML summary for many logs
├── test_data/
│   ├── sample_sim.log        # mixed run: 7 pass, 2 fail, 1 skip
│   ├── sample_pass.log       # every test passes
│   └── sample_fail.log       # 25 tests: 22 pass, 2 fail, 1 skip
├── output/                   # generated reports (git-ignored)
└── docs/
    └── USAGE.md
```

## Expected log format

```text
[2026-05-01 10:23:46] TEST PASS: rv32i-add (0.82s)
[2026-05-01 10:23:48] TEST FAIL: rv32i-sll (1.02s)
[2026-05-01 10:23:48] TEST SKIP: rv32i-srl (not supported)
```

Only `TEST PASS|FAIL|SKIP` lines are analyzed. `TEST START`, `ERROR`, `INFO` and the
final `SUMMARY` line are ignored (the `SUMMARY` line is only used as a sanity check).

## Git workflow used

Work was done on short-lived branches named with the MEDS convention
(`feature/`, `fix/`, `docs/`) and merged into `main` with `--no-ff` so the history
shows each piece of work. `feature/csv-output` and `feature/color-output` both edited
the option handling in `analyze.sh`; merging them produced a real conflict, which was
resolved by keeping both options. Inspect it with:

```bash
git log --oneline --graph --all
```

## Author

Aftab - MEDS Lab, Department of Electrical Engineering, UET Lahore.
