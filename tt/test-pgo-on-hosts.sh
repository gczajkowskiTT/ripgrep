#!/usr/bin/env bash
#
# test-pgo-on-hosts.sh - Test PGO-optimized ripgrep binary on all SOC hosts
#
# This script tests the PGO-optimized ripgrep binary on all machines found in
# /proj_soc/user_dev/socinfra/resource_summary.md to ensure compatibility.
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
mkdir -p "$SCRATCH_DIR"
PGO_BINARY="/proj_soc/user_dev/gczajkowski/bin/rg"
TEST_DIR="$SCRATCH_DIR/rg-test-$$"
RESULTS_FILE="$SCRIPT_DIR/pgo-test-results.txt"
FAILED_HOSTS_FILE="$SCRIPT_DIR/pgo-test-failed.txt"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Host list from resource_summary.md
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

# Counters
TOTAL_HOSTS=${#HOSTS[@]}
TESTED=0
PASSED=0
FAILED=0
UNREACHABLE=0

# Verify PGO binary exists
if [[ ! -f "$PGO_BINARY" ]]; then
    echo -e "${RED}Error: PGO binary not found at $PGO_BINARY${NC}"
    exit 1
fi

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Testing PGO-Optimized Ripgrep on SOC Hosts                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "PGO Binary: $PGO_BINARY"
echo "Binary Size: $(du -h "$PGO_BINARY" | cut -f1)"
echo "Total Hosts: $TOTAL_HOSTS"
echo ""
echo "Results will be saved to:"
echo "  - Success/Details: $RESULTS_FILE"
echo "  - Failed Hosts:    $FAILED_HOSTS_FILE"
echo ""

# Initialize results files
echo "# PGO Ripgrep Binary Test Results" > "$RESULTS_FILE"
echo "# Generated: $(date)" >> "$RESULTS_FILE"
echo "# Binary: $PGO_BINARY ($(du -h "$PGO_BINARY" | cut -f1))" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

echo "# Failed Hosts" > "$FAILED_HOSTS_FILE"
echo "# Generated: $(date)" >> "$FAILED_HOSTS_FILE"
echo "" >> "$FAILED_HOSTS_FILE"

# Function to test a single host
test_host() {
    local host=$1
    local result=""

    echo -ne "${BLUE}Testing $host...${NC} "

    # Check if host is reachable
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" "echo ok" &>/dev/null; then
        echo -e "${YELLOW}UNREACHABLE${NC}"
        echo "## $host - UNREACHABLE" >> "$RESULTS_FILE"
        echo "$host - UNREACHABLE" >> "$FAILED_HOSTS_FILE"
        ((UNREACHABLE++))
        return 1
    fi

    # Run tests on the host
    result=$(ssh -o ConnectTimeout=10 "$host" bash <<'REMOTE_SCRIPT'
        # Setup scratch directory on remote host
        SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
        mkdir -p "$SCRATCH_DIR"

        # Copy binary to temp location
        RG_BIN="$SCRATCH_DIR/rg-test-$$"

        # Test 1: Check if binary exists and is accessible
        if [[ ! -f "/proj_soc/user_dev/gczajkowski/bin/rg" ]]; then
            echo "ERROR: Binary not accessible on this host"
            exit 1
        fi

        cp /proj_soc/user_dev/gczajkowski/bin/rg "$RG_BIN"
        chmod +x "$RG_BIN"

        # Test 2: Check CPU info
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        CPU_FLAGS=$(grep "flags" /proc/cpuinfo | head -1)

        # Check for required CPU features
        HAS_AVX2=0
        if echo "$CPU_FLAGS" | grep -q " avx2 "; then
            HAS_AVX2=1
        fi

        # Test 3: Run --version
        VERSION_OUTPUT=$("$RG_BIN" --version 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "ERROR: --version failed: $VERSION_OUTPUT"
            rm -f "$RG_BIN"
            exit 1
        fi

        # Test 4: Run basic search
        TEST_FILE="$SCRATCH_DIR/rg-test-file-$$"
        echo -e "test line 1\npattern match here\ntest line 3" > "$TEST_FILE"

        SEARCH_OUTPUT=$("$RG_BIN" "pattern" "$TEST_FILE" 2>&1)
        SEARCH_EXIT=$?

        rm -f "$TEST_FILE"

        if [[ $SEARCH_EXIT -ne 0 ]]; then
            echo "ERROR: Basic search failed: $SEARCH_OUTPUT"
            rm -f "$RG_BIN"
            exit 1
        fi

        if [[ "$SEARCH_OUTPUT" != *"pattern match"* ]]; then
            echo "ERROR: Search output incorrect: $SEARCH_OUTPUT"
            rm -f "$RG_BIN"
            exit 1
        fi

        # Test 5: Quick performance test
        PERF_TEST=$(/usr/bin/time -f "%e" "$RG_BIN" "test" /etc/passwd 2>&1 >/dev/null | tail -1)

        # Cleanup
        rm -f "$RG_BIN"

        # Report success
        echo "SUCCESS"
        echo "CPU: $CPU_MODEL"
        echo "AVX2: $HAS_AVX2"
        echo "VERSION: $VERSION_OUTPUT"
        echo "PERF: ${PERF_TEST}s"
REMOTE_SCRIPT
    )

    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && [[ "$result" == *"SUCCESS"* ]]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        echo "## $host - PASSED" >> "$RESULTS_FILE"
        echo "$result" | tail -n +2 >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "## $host - FAILED" >> "$RESULTS_FILE"
        echo "$result" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"
        echo "$host - FAILED: $result" >> "$FAILED_HOSTS_FILE"
        ((FAILED++))
        return 1
    fi
}

# Test all hosts
echo -e "${YELLOW}Starting tests on $TOTAL_HOSTS hosts...${NC}"
echo ""

for host in "${HOSTS[@]}"; do
    test_host "$host" || true
    ((TESTED++))

    # Progress indicator
    if ((TESTED % 10 == 0)); then
        echo ""
        echo -e "${BLUE}Progress: $TESTED/$TOTAL_HOSTS hosts tested${NC}"
        echo ""
    fi
done

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                           TEST SUMMARY                                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Total Hosts:     $TOTAL_HOSTS"
echo "Tested:          $TESTED"
echo -e "${GREEN}Passed:          $PASSED${NC}"
echo -e "${RED}Failed:          $FAILED${NC}"
echo -e "${YELLOW}Unreachable:     $UNREACHABLE${NC}"
echo ""

if [[ $PASSED -eq $TOTAL_HOSTS ]]; then
    echo -e "${GREEN}✓ All hosts passed! PGO binary is compatible across all machines.${NC}"
    SUCCESS_RATE=100
elif [[ $FAILED -gt 0 ]]; then
    SUCCESS_RATE=$((PASSED * 100 / (PASSED + FAILED)))
    echo -e "${YELLOW}⚠ Some hosts failed. Success rate: ${SUCCESS_RATE}%${NC}"
    echo ""
    echo "Failed hosts are listed in: $FAILED_HOSTS_FILE"
else
    SUCCESS_RATE=$((PASSED * 100 / TOTAL_HOSTS))
    echo -e "${YELLOW}Some hosts were unreachable. Success rate: ${SUCCESS_RATE}%${NC}"
fi

echo ""
echo "Detailed results saved to: $RESULTS_FILE"
echo ""

# Write summary to results file
{
    echo ""
    echo "# SUMMARY"
    echo "Total Hosts:     $TOTAL_HOSTS"
    echo "Tested:          $TESTED"
    echo "Passed:          $PASSED"
    echo "Failed:          $FAILED"
    echo "Unreachable:     $UNREACHABLE"
    echo "Success Rate:    ${SUCCESS_RATE}%"
} >> "$RESULTS_FILE"

# Exit with appropriate code
if [[ $FAILED -gt 0 ]]; then
    exit 1
elif [[ $UNREACHABLE -gt 0 ]]; then
    exit 2
else
    exit 0
fi
