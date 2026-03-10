#!/usr/bin/env bash
#
# parallel-test-hosts.sh - Test PGO binary on all hosts in parallel
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PGO_BINARY="/proj_soc/user_dev/gczajkowski/bin/rg"
RESULTS_DIR="$SCRIPT_DIR/test-results"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

# All hosts from resource_summary.md
HOSTS=(
    soc-c-02 soc-c-03 soc-c-04 soc-c-05 soc-c-06 soc-c-07 soc-c-08 soc-c-09
    soc-c-12 soc-c-13 soc-c-14 soc-c-15 soc-c-16 soc-c-17 soc-c-18 soc-c-19
    soc-c-20 soc-c-21 soc-c-22 soc-c-23 soc-c-24 soc-c-25 soc-c-26 soc-c-27
    soc-c-28 soc-c-29 soc-c-30 soc-c-31 soc-c-32
    soc-l-01 soc-l-02 soc-l-03 soc-l-04 soc-l-05 soc-l-06 soc-l-07 soc-l-09
    soc-l-10 soc-l-11 soc-l-12
    soc-zebu-01 soc-zebu-02 soc-zebu-03 soc-zebu-04
    socinfra
)

mkdir -p "$RESULTS_DIR"
rm -f "$RESULTS_DIR"/*.result

echo "Testing PGO ripgrep binary on ${#HOSTS[@]} hosts in parallel..."
echo "Results directory: $RESULTS_DIR"
echo ""

# Function to test a host
test_host() {
    local host=$1
    local result_file="$RESULTS_DIR/${host}.result"

    {
        echo "HOST: $host"
        echo "TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S')"

        # Test 1: Version check
        version_output=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
            "$PGO_BINARY --version" 2>&1)
        version_exit=$?

        if [[ $version_exit -ne 0 ]]; then
            echo "STATUS: FAILED"
            echo "ERROR: Version check failed"
            echo "OUTPUT: $version_output"
            exit 1
        fi

        if ! echo "$version_output" | grep -q "ripgrep"; then
            echo "STATUS: FAILED"
            echo "ERROR: Invalid version output"
            echo "OUTPUT: $version_output"
            exit 1
        fi

        # Test 2: Basic search
        search_output=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
            "$PGO_BINARY 'root' /etc/passwd" 2>&1 | head -3)
        search_exit=$?

        if [[ $search_exit -ne 0 ]] && [[ $search_exit -ne 1 ]]; then
            echo "STATUS: FAILED"
            echo "ERROR: Search test failed with exit code $search_exit"
            echo "OUTPUT: $search_output"
            exit 1
        fi

        # Test 3: CPU info
        cpu_info=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
            "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs" 2>&1)

        avx2_support=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
            "grep -q ' avx2 ' /proc/cpuinfo && echo 'YES' || echo 'NO'" 2>&1)

        # Success
        echo "STATUS: PASSED"
        echo "VERSION: $(echo "$version_output" | head -1)"
        echo "CPU: $cpu_info"
        echo "AVX2: $avx2_support"

    } > "$result_file" 2>&1
}

# Export function and variables for parallel execution
export -f test_host
export PGO_BINARY RESULTS_DIR

# Run tests in parallel (max 20 at a time)
printf '%s\n' "${HOSTS[@]}" | xargs -n 1 -P 20 -I {} bash -c 'test_host "$@"' _ {}

echo ""
echo "Waiting for all tests to complete..."
wait

echo ""
echo "Processing results..."

# Collect results
PASSED=0
FAILED=0
TOTAL=0

{
    echo "# PGO Ripgrep Binary Test Summary"
    echo "# Generated: $(date)"
    echo "# Binary: $PGO_BINARY"
    echo ""
    echo "## Results"
    echo ""
} > "$SUMMARY_FILE"

for host in "${HOSTS[@]}"; do
    result_file="$RESULTS_DIR/${host}.result"
    ((TOTAL++))

    if [[ -f "$result_file" ]]; then
        status=$(grep "^STATUS:" "$result_file" | cut -d' ' -f2)

        if [[ "$status" == "PASSED" ]]; then
            ((PASSED++))
            version=$(grep "^VERSION:" "$result_file" | cut -d' ' -f2-)
            cpu=$(grep "^CPU:" "$result_file" | cut -d' ' -f2-)
            avx2=$(grep "^AVX2:" "$result_file" | cut -d' ' -f2-)

            echo "✓ $host - PASSED (CPU: $cpu, AVX2: $avx2)"
            echo "- $host: PASSED | $cpu | AVX2: $avx2" >> "$SUMMARY_FILE"
        else
            ((FAILED++))
            error=$(grep "^ERROR:" "$result_file" | cut -d' ' -f2-)
            echo "✗ $host - FAILED: $error"
            echo "- $host: FAILED | $error" >> "$SUMMARY_FILE"
        fi
    else
        ((FAILED++))
        echo "✗ $host - NO RESULT (unreachable or timeout)"
        echo "- $host: NO RESULT (unreachable or timeout)" >> "$SUMMARY_FILE"
    fi
done

# Write summary
{
    echo ""
    echo "## Summary"
    echo "Total Hosts: $TOTAL"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Success Rate: $((PASSED * 100 / TOTAL))%"
} >> "$SUMMARY_FILE"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║          TEST SUMMARY                ║"
echo "╚══════════════════════════════════════╝"
echo "Total Hosts:  $TOTAL"
echo "Passed:       $PASSED"
echo "Failed:       $FAILED"
echo "Success Rate: $((PASSED * 100 / TOTAL))%"
echo ""
echo "Detailed results: $SUMMARY_FILE"
echo "Individual results: $RESULTS_DIR/*.result"

if [[ $FAILED -eq 0 ]]; then
    echo ""
    echo "✓ All hosts passed!"
    exit 0
else
    echo ""
    echo "⚠ Some hosts failed. Check $SUMMARY_FILE for details."
    exit 1
fi
