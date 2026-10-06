#!/bin/bash
#
# generate_report.sh - Analyze every log in a directory and write summary reports
#
# Runs analyze.sh (CSV mode) on each *.log file and produces
#   <output_dir>/summary.txt    plain-text table
#   <output_dir>/summary.html   HTML table (green/red rows)
#
# Usage: generate_report.sh [-i input_dir] [-o output_dir] [-f text|html|both] [-h]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANALYZE="$SCRIPT_DIR/analyze.sh"

INPUT_DIR="$PROJECT_ROOT/test_data"
OUTPUT_DIR="$PROJECT_ROOT/output"
FORMAT="both"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [-i input_dir] [-o output_dir] [-f text|html|both] [-h]

  -i DIR   Directory containing *.log files (default: test_data)
  -o DIR   Directory for the generated reports (default: output)
  -f FMT   Report format: text, html or both (default: both)
  -h       Show this help
USAGE
}

die() {
    echo "Error: $*" >&2
    exit 2
}

# html_escape - minimal escaping so log names cannot break the page
html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# analyze_row <log> - print the CSV data row for one log (header removed).
# analyze.sh exits 1 when tests fail; that is a normal result here. Only exit
# code 2 (bad input) is treated as a real error.
analyze_row() {
    local log="$1" rc=0 out
    out=$("$ANALYZE" --format csv "$log") || rc=$?
    if [ "$rc" -gt 1 ]; then
        die "analysis failed for $log (exit code $rc)"
    fi
    printf '%s\n' "$out" | tail -n 1
}

# collect_rows - one CSV row per log file in INPUT_DIR
collect_rows() {
    local log found=0
    for log in "$INPUT_DIR"/*.log; do
        [ -e "$log" ] || break
        found=1
        analyze_row "$log"
    done
    [ "$found" -eq 1 ] || die "no .log files found in $INPUT_DIR"
}

# write_text <rows> <file>
write_text() {
    local rows="$1" file="$2"
    {
        echo "=== RISC-V Log Analyzer - Summary Report ==="
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        printf '%-18s %5s %5s %5s %5s %7s %8s\n' "Log" "Total" "Pass" "Fail" "Skip" "Rate%" "Avg(s)"
        # CSV columns: 1 log, 2 total, 3 pass, 4 fail, 5 skip, 6 rate, 7 min, 8 max, 9 avg, 10 failed
        printf '%s\n' "$rows" | awk -F, '{
            n = split($1, p, "/")
            printf "%-18s %5d %5d %5d %5d %7s %8s\n", p[n], $2, $3, $4, $5, $6, $9
            t += $2; a += $3; f += $4; s += $5
        } END {
            printf "%-18s %5d %5d %5d %5d\n", "TOTAL", t, a, f, s
        }'
        echo
        echo "Failing tests:"
        printf '%s\n' "$rows" | awk -F, '$4 > 0 {
            n = split($1, p, "/"); gsub(/;/, ", ", $10)
            printf "  %s: %s\n", p[n], $10; any = 1
        } END { if (!any) print "  none" }'
    } > "$file"
}

# write_html <rows> <file>
write_html() {
    local rows="$1" file="$2"
    local log total pass fail skip rate min max avg failed cls name
    {
        cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>RISC-V Log Analyzer - Summary</title>
<style>
  body { font-family: sans-serif; margin: 2rem; }
  table { border-collapse: collapse; }
  th, td { border: 1px solid #ccc; padding: 6px 12px; text-align: right; }
  th { background: #222; color: #fff; }
  td.name, td.failed { text-align: left; }
  tr.ok { background: #e6f7e6; }
  tr.fail { background: #fde8e8; }
</style>
</head>
<body>
<h1>RISC-V Simulation Log Summary</h1>
<p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
<table>
<tr><th>Log</th><th>Total</th><th>Pass</th><th>Fail</th><th>Skip</th><th>Pass rate</th><th>Min (s)</th><th>Max (s)</th><th>Avg (s)</th><th>Failed tests</th></tr>
HTML
        while IFS=, read -r log total pass fail skip rate min max avg failed; do
            if [ "$fail" -gt 0 ]; then cls="fail"; else cls="ok"; fi
            name=$(basename "$log" | html_escape)
            failed=$(printf '%s' "${failed//;/, }" | html_escape)
            echo "<tr class=\"$cls\"><td class=\"name\">$name</td><td>$total</td><td>$pass</td><td>$fail</td><td>$skip</td><td>$rate%</td><td>$min</td><td>$max</td><td>$avg</td><td class=\"failed\">$failed</td></tr>"
        done <<< "$rows"
        echo "</table>"
        echo "</body>"
        echo "</html>"
    } > "$file"
}

main() {
    local opt rows
    while getopts ":i:o:f:h" opt; do
        case "$opt" in
            i) INPUT_DIR="$OPTARG" ;;
            o) OUTPUT_DIR="$OPTARG" ;;
            f) FORMAT="$OPTARG" ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            \?) die "unknown option: -$OPTARG" ;;
        esac
    done

    case "$FORMAT" in
        text|html|both) ;;
        *) die "invalid format '$FORMAT' (expected: text, html or both)" ;;
    esac
    [ -d "$INPUT_DIR" ] || die "input directory not found: $INPUT_DIR"

    mkdir -p "$OUTPUT_DIR"
    rows=$(collect_rows)

    if [ "$FORMAT" = "text" ] || [ "$FORMAT" = "both" ]; then
        write_text "$rows" "$OUTPUT_DIR/summary.txt"
        echo "Wrote $OUTPUT_DIR/summary.txt"
    fi
    if [ "$FORMAT" = "html" ] || [ "$FORMAT" = "both" ]; then
        write_html "$rows" "$OUTPUT_DIR/summary.html"
        echo "Wrote $OUTPUT_DIR/summary.html"
    fi
}

main "$@"
