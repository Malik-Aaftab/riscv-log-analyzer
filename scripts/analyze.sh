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
}

main() {
    parse_args "$@"

    TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/meds_analyze.XXXXXX")
    trap cleanup EXIT
    RESULTS_FILE="$TMP_DIR/results.txt"

    log_verbose "Analyzing: $LOG_FILE"
    log_verbose "Parsing is not implemented yet"
    echo "$SCRIPT_NAME: '$LOG_FILE' accepted (analysis not implemented yet)"
    return 0
}

main "$@"
