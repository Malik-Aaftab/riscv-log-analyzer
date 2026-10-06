# USAGE - riscv-log-analyzer command reference

All commands are run from the repository root. Run `make setup` once after cloning.

## 1. `scripts/analyze.sh`

```text
analyze.sh <log_file> [options]
```

| Argument / option     | Description                                                      |
|-----------------------|------------------------------------------------------------------|
| `<log_file>`          | Path to the simulation log. **Required.**                        |
| `--format <text\|csv>`| Output format. Default `text`.                                   |
| `--output <path>`     | Write the report to `<path>` (parent folders are created). Default: stdout. |
| `-v`, `--verbose`     | Diagnostics on stderr, plus a per-test table in the text report. |
| `--color`             | ANSI colours: green PASS, red FAIL (text output).                |
| `--compare <old.log>` | Add a regression/fix section by comparing with an older log (text format only). |
| `-h`, `--help`        | Show help and exit 0.                                            |

Options and the log file may appear in any order. Both `--format csv` and the log path
can come first.

### Exit codes

| Code | Meaning                                                              |
|------|----------------------------------------------------------------------|
| 0    | Every test passed (skips do not count as failures)                   |
| 1    | At least one test failed                                             |
| 2    | Usage or input problem: missing/unreadable file, bad option, no test results in the file |

The code is the same whether the report goes to stdout or to `--output`.

### What is extracted

1. Total number of tests run (PASS + FAIL + SKIP)
2. Count of PASS, FAIL and SKIP results
3. Pass rate as a percentage (of all tests, one decimal)
4. Names of all failing tests, in log order
5. Execution time per test (from the `(0.82s)` suffix; SKIPs have none)
6. Minimum, maximum (with test names) and average execution time

### Text report

See the sample in the README. Sections: *Results Summary*, *Failed Tests* (only if
something failed), *Per-Test Results* (only with `--verbose`), *Timing Statistics*,
*Comparison* (only with `--compare`) and the final *Verdict* with the exit code.

### CSV report

One header row and one data row:

| Column         | Meaning                                       |
|----------------|-----------------------------------------------|
| `log_file`     | Path as given on the command line             |
| `total`        | Tests run                                     |
| `passed`, `failed`, `skipped` | Result counts                  |
| `pass_rate`    | Percentage, one decimal                       |
| `min_time`, `max_time`, `avg_time` | Seconds (`NA` if the log has no timing) |
| `failed_tests` | Failing test names joined with `;`            |

### Examples

```bash
./scripts/analyze.sh test_data/sample_pass.log
./scripts/analyze.sh test_data/sample_fail.log --format csv
./scripts/analyze.sh test_data/sample_fail.log --output output/report.txt --verbose
./scripts/analyze.sh test_data/sample_fail.log --compare test_data/sample_pass.log
echo "exit code: $?"
```

### Error messages

| Situation                          | Message (stderr)                                         | Exit |
|------------------------------------|----------------------------------------------------------|------|
| No arguments                       | `Error: missing required argument: <log_file>`           | 2    |
| File does not exist                | `Error: log file not found: <path>`                      | 2    |
| Bad `--format` value               | `Error: invalid format 'xml' (expected: text or csv)`    | 2    |
| Unknown option                     | `Error: unknown option: --bogus`                         | 2    |
| File without any TEST result lines | `Error: no TEST PASS/FAIL/SKIP entries found in '<path>'`| 2    |
| `SUMMARY:` line disagrees with parsed count | `Warning: log SUMMARY reports N tests but M results were parsed` (analysis continues) | unchanged |

## 2. `scripts/generate_report.sh`

Analyzes every `*.log` in a directory and writes `summary.txt` and/or `summary.html`.

```text
generate_report.sh [-i input_dir] [-o output_dir] [-f text|html|both] [-h]
```

| Flag  | Description                                   | Default     |
|-------|-----------------------------------------------|-------------|
| `-i`  | Directory containing `.log` files             | `test_data` |
| `-o`  | Directory for generated reports               | `output`    |
| `-f`  | `text`, `html` or `both`                      | `both`      |
| `-h`  | Show help                                     |             |

The script exits 0 even if some logs contain failing tests (those are reported, not
treated as script errors); it exits 2 for bad arguments or a missing directory.

## 3. `scripts/setup_env.sh`

Checks for `bash` 4+, `grep`, `sed`, `awk`, `sort`, `tr`, `date`, `mktemp`, `make`
(required) and `git`, `shellcheck` (optional). It also makes all scripts executable and
creates `output/`. Exit code 1 if a required tool is missing.

## 4. Makefile

| Target        | Description                                                       |
|---------------|-------------------------------------------------------------------|
| `make all`    | Run the analyzer on every log in `test_data/` and print the reports |
| `make test`   | Verify exit code and counts of each sample log, plus the missing-file error path |
| `make report` | Build `output/<log>.txt` (pattern rule) and `output/summary.{txt,html}` |
| `make clean`  | Delete generated `.txt`, `.html`, `.csv` files in `output/`       |
| `make help`   | Print all targets with descriptions                               |
| `make setup`  | Run `setup_env.sh`                                                |
| `make print-VAR` | Debug helper, e.g. `make print-LOGS`                           |

Variables can be overridden: `make DATA_DIR=my_logs report`.

## 5. Troubleshooting

- **`Permission denied` when running a script** - run `make setup` or `chmod +x scripts/*.sh`.
- **`make: *** missing separator`** - a recipe line was indented with spaces instead of a TAB.
- **`no TEST PASS/FAIL/SKIP entries found`** - the file is not in the expected format (see README).
- **Output files show up in `git status`** - they should not; `output/*` is git-ignored except `output/.gitkeep`.

## 6. Design notes

- Every script starts with `set -euo pipefail`. Because `grep` exits 1 when it finds
  nothing, calls that may legitimately match nothing are guarded with `|| true`.
- Temp files live in a `mktemp -d` directory that a `trap ... EXIT` handler always removes.
- `analyze.sh` uses functions (`parse_args`, `extract_results`, `compute_stats`,
  `render_text`, `render_csv`, ...) so each step can be read and changed on its own.
- Exit code 2 (input error) is deliberately different from 1 (tests failed), so callers
  can tell "the analyzer broke" from "the design has failing tests".
