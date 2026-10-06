#!/bin/bash
#
# setup_env.sh - Verify the environment for riscv-log-analyzer
#
# Checks that every tool the scripts depend on is installed, makes the scripts
# executable and creates the output/ directory.
#
# Usage: ./scripts/setup_env.sh
# Exit code: 0 if the environment is ready, 1 if a required tool is missing.

set -euo pipefail

# Resolve paths relative to this file so the script works from any directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

REQUIRED_TOOLS=(bash grep sed awk sort tr date mktemp make)
OPTIONAL_TOOLS=(git shellcheck)

MISSING=0

# check_bash_version - the scripts use features that need bash 4+
check_bash_version() {
    if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
        printf '  [ok]       %-10s %s\n' "bash>=4" "$BASH_VERSION"
    else
        printf '  [MISSING]  %-10s found %s\n' "bash>=4" "$BASH_VERSION"
        MISSING=$((MISSING + 1))
    fi
}

# check_tools <label> <required|optional> <tool...>
check_tools() {
    local kind="$1" tool
    shift
    for tool in "$@"; do
        if command -v "$tool" > /dev/null 2>&1; then
            printf '  [ok]       %-10s %s\n' "$tool" "$(command -v "$tool")"
        elif [ "$kind" = "required" ]; then
            printf '  [MISSING]  %-10s (required)\n' "$tool"
            MISSING=$((MISSING + 1))
        else
            printf '  [skip]     %-10s (optional, not installed)\n' "$tool"
        fi
    done
}

# prepare_project - make scripts executable and create the output directory
prepare_project() {
    chmod +x "$SCRIPT_DIR"/*.sh
    mkdir -p "$PROJECT_ROOT/output"
    echo "  [ok]       scripts are executable, output/ exists"
}

main() {
    echo "=== riscv-log-analyzer environment check ==="
    echo "Required tools:"
    check_bash_version
    check_tools required "${REQUIRED_TOOLS[@]}"
    echo "Optional tools:"
    check_tools optional "${OPTIONAL_TOOLS[@]}"
    echo "Project:"
    prepare_project
    echo

    if [ "$MISSING" -gt 0 ]; then
        echo "Setup FAILED: $MISSING required tool(s) missing." >&2
        echo "On Ubuntu try: sudo apt install build-essential gawk grep sed coreutils" >&2
        exit 1
    fi
    echo "Environment OK."
}

main "$@"
