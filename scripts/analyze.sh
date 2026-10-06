#!/bin/bash
#
# analyze.sh - Analyze a RISC-V simulation log file
#
# Usage: ./analyze.sh <log_file> [options]     (see --help)
#
# Exit codes:
#   0  all tests passed
#   1  at least one test failed
#   2  usage or input error (bad arguments, unreadable file, no results found)
#
# Author: YOUR NAME
# MEDS Lab Module 1 - Grand Assignment

set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# ---------- Defaults ----------
VERBOSE=0
FORMAT="text"
OUTPUT=""
LOG_FILE=""
TMP_DIR=""

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <log_file> [options]

Analyze a RISC-V simulation log and report pass/fail statistics.

Arguments:
  <log_file>          Path to the simulation log (required)

Options:
  -v, --verbose       Print extra diagnostics (per-test results, progress)
  --format <fmt>      Output format: text or csv (default: text)
  --output <path>     Write the report to <path> (default: stdout)
  -h, --help          Show this help and exit

Exit codes:
  0  all tests passed
  1  at least one test failed
  2  usage or input error
EOF
}

# log_verbose <message...>
# Diagnostics go to stderr so they never pollute the report on stdout.
log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[verbose] $*" >&2
    fi
}

# die <message...> - print an error and exit with code 2 (usage/input error)
die() {
    echo "Error: $*" >&2
    echo "Try '$SCRIPT_NAME --help' for usage." >&2
    exit 2
}

# cleanup - remove the temp directory; registered with 'trap ... EXIT'
cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

parse_args() {
    if [ $# -eq 0 ]; then
        die "missing required argument: <log_file>"
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --format)
                [ $# -ge 2 ] || die "--format requires an argument (text|csv)"
                FORMAT="$2"
                shift 2
                ;;
            --output)
                [ $# -ge 2 ] || die "--output requires a file path"
                OUTPUT="$2"
                shift 2
                ;;
            -*)
                die "unknown option: $1"
                ;;
            *)
                [ -z "$LOG_FILE" ] || die "only one log file allowed (got '$LOG_FILE' and '$1')"
                LOG_FILE="$1"
                shift
                ;;
        esac
    done

    [ -n "$LOG_FILE" ] || die "missing required argument: <log_file>"
    [ -e "$LOG_FILE" ] || die "log file not found: $LOG_FILE"
    [ -f "$LOG_FILE" ] || die "not a regular file: $LOG_FILE"
    [ -r "$LOG_FILE" ] || die "log file is not readable: $LOG_FILE"
    case "$FORMAT" in
        text|csv) ;;
        *) die "invalid format '$FORMAT' (expected: text or csv)" ;;
    esac
}

# extract_results <log> <out>
# Reduce every "TEST PASS/FAIL/SKIP" line to:  STATUS name [seconds]
# START and ERROR lines are ignored on purpose. A SKIP line has no time, so it
# ends up with only two fields.
extract_results() {
    local log="$1" out="$2"
    # tr strips Windows line endings. The trailing '|| true' is needed because
    # grep exits 1 when nothing matches, and pipefail would abort the script.
    tr -d '\r' < "$log" \
        | grep -E 'TEST (PASS|FAIL|SKIP):' \
        | sed -E 's/^\[[^]]*\] TEST (PASS|FAIL|SKIP): ([^ ]+)( \(([0-9]+(\.[0-9]+)?)s\))?.*$/\1 \2 \4/' \
        > "$out" || true
}

# compute_stats <results_file>
# Fills the globals TOTAL PASS FAIL SKIP FAILED_TESTS and the timing values.
compute_stats() {
    local results="$1"

    # One awk pass counts each status ("p+f+s" makes unset counters print as 0)
    read -r TOTAL PASS FAIL SKIP < <(awk '
        $1 == "PASS" { p++ }
        $1 == "FAIL" { f++ }
        $1 == "SKIP" { s++ }
        END { printf "%d %d %d %d\n", p + f + s, p, f, s }
    ' "$results")

    # Names of failing tests, one per line (empty string when nothing failed)
    FAILED_TESTS=$(awk '$1 == "FAIL" { print $2 }' "$results")

    # Timing: only lines with a 3rd field carry an execution time (SKIPs do not)
    read -r MIN_T MIN_N MAX_T MAX_N AVG_T TIMED < <(awk '
        NF >= 3 {
            t = $3 + 0
            if (n == 0 || t < min) { min = t; minn = $2 }
            if (n == 0 || t > max) { max = t; maxn = $2 }
            sum += t
            n++
        }
        END {
            if (n == 0) print "NA NA NA NA NA 0"
            else printf "%.2f %s %.2f %s %.2f %d\n", min, minn, max, maxn, sum / n, n
        }
    ' "$results")
}

# percent <part> <whole> - one-decimal percentage, safe when whole is 0
percent() {
    awk -v n="$1" -v t="$2" 'BEGIN { if (t == 0) printf "0.0"; else printf "%.1f", n * 100 / t }'
}

# render_text - the human-readable report (matches the assignment's example)
render_text() {
    local pass_pct fail_pct skip_pct
    pass_pct=$(percent "$PASS" "$TOTAL")
    fail_pct=$(percent "$FAIL" "$TOTAL")
    skip_pct=$(percent "$SKIP" "$TOTAL")

    echo "=== RISC-V Simulation Log Analysis ==="
    echo "Log file: $LOG_FILE"
    echo "Analysis date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo "--- Results Summary ---"
    printf 'Total tests: %d\n' "$TOTAL"
    printf '%-9s%6d (%4s%%)\n' "Passed:" "$PASS" "$pass_pct"
    printf '%-9s%6d (%4s%%)\n' "Failed:" "$FAIL" "$fail_pct"
    printf '%-9s%6d (%4s%%)\n' "Skipped:" "$SKIP" "$skip_pct"
    echo

    if [ "$FAIL" -gt 0 ]; then
        echo "--- Failed Tests ---"
        local i=1 name
        while IFS= read -r name; do
            printf '  %d. %s\n' "$i" "$name"
            i=$((i + 1))
        done <<< "$FAILED_TESTS"
        echo
    fi

    if [ "$VERBOSE" -eq 1 ]; then
        echo "--- Per-Test Results ---"
        awk '{ printf "  %-6s %-16s %s\n", $1, $2, (NF >= 3 ? $3 "s" : "-") }' "$RESULTS_FILE"
        echo
    fi

    echo "--- Timing Statistics ---"
    if [ "$TIMED" -gt 0 ]; then
        printf 'Min time:  %ss (%s)\n' "$MIN_T" "$MIN_N"
        printf 'Max time:  %ss (%s)\n' "$MAX_T" "$MAX_N"
        printf 'Avg time:  %ss\n' "$AVG_T"
    else
        echo "No timing information found in log"
    fi
    echo

    if [ "$FAIL" -gt 0 ]; then
        echo "--- Verdict: FAIL ---"
    else
        echo "--- Verdict: PASS ---"
    fi
    echo "Exit code: $EXIT_CODE"
}

# render_csv - a header row plus one summary row; failing tests are joined with ';'
render_csv() {
    local failed_joined
    failed_joined=$(printf '%s' "$FAILED_TESTS" | tr '\n' ';')
    echo "log_file,total,passed,failed,skipped,pass_rate,min_time,max_time,avg_time,failed_tests"
    printf '%s,%d,%d,%d,%d,%s,%s,%s,%s,%s\n' \
        "$LOG_FILE" "$TOTAL" "$PASS" "$FAIL" "$SKIP" \
        "$(percent "$PASS" "$TOTAL")" "$MIN_T" "$MAX_T" "$AVG_T" "$failed_joined"
}

# emit - print the report in the selected format
emit() {
    case "$FORMAT" in
        csv) render_csv ;;
        *)   render_text ;;
    esac
}

main() {
    parse_args "$@"

    TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/meds_analyze.XXXXXX")
    trap cleanup EXIT
    RESULTS_FILE="$TMP_DIR/results.txt"

    log_verbose "Analyzing: $LOG_FILE"
    extract_results "$LOG_FILE" "$RESULTS_FILE"
    [ -s "$RESULTS_FILE" ] || die "no TEST PASS/FAIL/SKIP entries found in '$LOG_FILE'"
    log_verbose "Extracted $(wc -l < "$RESULTS_FILE") test results"
    compute_stats "$RESULTS_FILE"
    log_verbose "Parsed $TOTAL tests: $PASS passed, $FAIL failed, $SKIP skipped"

    # The exit code reflects the test outcome, not whether the script itself worked
    EXIT_CODE=0
    if [ "$FAIL" -gt 0 ]; then
        EXIT_CODE=1
    fi

    if [ -n "$OUTPUT" ]; then
        mkdir -p "$(dirname "$OUTPUT")"
        emit > "$OUTPUT"
        log_verbose "Report written to $OUTPUT"
    else
        emit
    fi

    exit "$EXIT_CODE"
}

main "$@"
