#!/usr/bin/env bash
#
# test-rg-all-hosts.sh - Test PGO ripgrep binary on all hosts from resource_summary.json
#
# Uses SSH connection optimizations from ttautomation/infra/soc_health_monitor.py:
# - Extended timeouts (ConnectTimeout=30)
# - Connection keepalive (ServerAliveInterval=10, ServerAliveCountMax=3)
# - Optimized SSH options for batch operations
# - Retry logic with configurable attempts
#

set -uo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PGO_BINARY="/proj_soc/user_dev/gczajkowski/bin/rg"
RESULTS_DIR="$SCRIPT_DIR/test-results-extended"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"
JSON_SOURCE="/proj_soc/user_dev/socinfra/resource_summary.json"

# SSH configuration from ttautomation/infra/soc_health_monitor.py
SSH_CONNECT_TIMEOUT=30  # Extended from 15 to 30 seconds
SSH_COMMAND_TIMEOUT=60  # Overall command timeout
SSH_RETRY_ATTEMPTS=3
SSH_RETRY_DELAY=2

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Extract ALL hosts from JSON using jq (from machines.hosts array)
echo "Extracting hosts from $JSON_SOURCE..."
HOSTS=($(jq -r '.machines.hosts[]' "$JSON_SOURCE" 2>/dev/null | sort -u))

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No hosts found in JSON file${NC}"
    exit 1
fi

TOTAL_HOSTS=${#HOSTS[@]}

echo "Found $TOTAL_HOSTS hosts to test"
echo ""

mkdir -p "$RESULTS_DIR"
rm -f "$RESULTS_DIR"/*.result

# Build optimized SSH command
# Based on ttautomation/infra/soc_health_monitor.py build_ssh_cmd()
build_ssh_cmd() {
    local host=$1
    local command=$2

    echo ssh \
        -T \
        -x \
        -o ConnectTimeout=$SSH_CONNECT_TIMEOUT \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=10 \
        -o ServerAliveCountMax=3 \
        -o PasswordAuthentication=no \
        -o LogLevel=ERROR \
        "$host" \
        "$command"
}

# Test function with retry logic
test_host_with_retry() {
    local host=$1
    local result_file="$RESULTS_DIR/${host}.result"
    local attempt=1
    local success=false

    {
        echo "HOST: $host"
        echo "TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "ATTEMPTS: $SSH_RETRY_ATTEMPTS"
        echo ""

        # Retry loop
        while [[ $attempt -le $SSH_RETRY_ATTEMPTS ]]; do
            echo "=== Attempt $attempt/$SSH_RETRY_ATTEMPTS ==="

            # Test 1: Version check with timeout
            local version_output
            local ssh_cmd

            ssh_cmd=$(build_ssh_cmd "$host" "$PGO_BINARY --version")
            version_output=$(timeout $SSH_COMMAND_TIMEOUT $ssh_cmd 2>&1)
            version_exit=$?

            if [[ $version_exit -eq 0 ]] && echo "$version_output" | grep -q "ripgrep"; then
                echo "Version check: SUCCESS"
                echo "Version: $(echo "$version_output" | head -1)"

                # Test 2: Basic search
                ssh_cmd=$(build_ssh_cmd "$host" "$PGO_BINARY 'root' /etc/passwd 2>&1 | head -3")
                search_output=$(timeout $SSH_COMMAND_TIMEOUT $ssh_cmd 2>&1)
                search_exit=$?

                if [[ $search_exit -eq 0 ]] || [[ $search_exit -eq 1 ]]; then
                    echo "Search test: SUCCESS"

                    # Test 3: CPU info
                    ssh_cmd=$(build_ssh_cmd "$host" "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs")
                    cpu_info=$(timeout $SSH_COMMAND_TIMEOUT $ssh_cmd 2>&1)

                    ssh_cmd=$(build_ssh_cmd "$host" "grep -q ' avx2 ' /proc/cpuinfo && echo 'YES' || echo 'NO'")
                    avx2_support=$(timeout $SSH_COMMAND_TIMEOUT $ssh_cmd 2>&1)

                    # Mark success
                    echo ""
                    echo "STATUS: PASSED"
                    echo "CPU: $cpu_info"
                    echo "AVX2: $avx2_support"
                    success=true
                    break
                else
                    echo "Search test: FAILED (exit code: $search_exit)"
                fi
            else
                echo "Version check: FAILED (exit code: $version_exit)"
                echo "Output: $version_output"
            fi

            # Wait before retry (except on last attempt)
            if [[ $attempt -lt $SSH_RETRY_ATTEMPTS ]]; then
                echo "Waiting ${SSH_RETRY_DELAY}s before retry..."
                sleep $SSH_RETRY_DELAY
            fi

            ((attempt++))
        done

        if [[ $success == false ]]; then
            echo ""
            echo "STATUS: FAILED"
            echo "ERROR: All $SSH_RETRY_ATTEMPTS attempts failed"
        fi

    } > "$result_file" 2>&1
}

# Export functions and variables for parallel execution
export -f build_ssh_cmd
export -f test_host_with_retry
export PGO_BINARY RESULTS_DIR SSH_CONNECT_TIMEOUT SSH_COMMAND_TIMEOUT SSH_RETRY_ATTEMPTS SSH_RETRY_DELAY

echo -e "${YELLOW}Testing $TOTAL_HOSTS hosts in parallel with optimized SSH settings...${NC}"
echo "SSH ConnectTimeout: ${SSH_CONNECT_TIMEOUT}s"
echo "Command Timeout: ${SSH_COMMAND_TIMEOUT}s"
echo "Retry Attempts: $SSH_RETRY_ATTEMPTS"
echo ""

# Run tests in parallel (max 20 at a time to avoid overwhelming network)
printf '%s\n' "${HOSTS[@]}" | xargs -n 1 -P 20 -I {} bash -c 'test_host_with_retry "$@"' _ {}

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
    echo "# PGO Ripgrep Binary Test Summary (Extended SSH Timeouts)"
    echo "# Generated: $(date)"
    echo "# Binary: $PGO_BINARY"
    echo "# Source: $JSON_SOURCE"
    echo "# SSH Settings: ConnectTimeout=${SSH_CONNECT_TIMEOUT}s, CommandTimeout=${SSH_COMMAND_TIMEOUT}s, Retries=$SSH_RETRY_ATTEMPTS"
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
            version=$(grep "^Version:" "$result_file" | cut -d' ' -f2-)
            cpu=$(grep "^CPU:" "$result_file" | cut -d' ' -f2-)
            avx2=$(grep "^AVX2:" "$result_file" | cut -d' ' -f2-)
            attempts=$(grep "^=== Attempt" "$result_file" | wc -l)

            echo -e "${GREEN}✓${NC} $host - PASSED (CPU: $cpu, AVX2: $avx2, Attempts: $attempts)"
            echo "- $host: PASSED | $cpu | AVX2: $avx2 | Attempts: $attempts" >> "$SUMMARY_FILE"
        else
            ((FAILED++))
            error=$(grep "^ERROR:" "$result_file" | cut -d' ' -f2- | head -1)
            attempts=$(grep "^=== Attempt" "$result_file" | wc -l)

            echo -e "${RED}✗${NC} $host - FAILED: $error (Attempts: $attempts)"
            echo "- $host: FAILED | $error | Attempts: $attempts" >> "$SUMMARY_FILE"
        fi
    else
        ((FAILED++))
        echo -e "${RED}✗${NC} $host - NO RESULT (test did not complete)"
        echo "- $host: NO RESULT" >> "$SUMMARY_FILE"
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
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    TEST SUMMARY                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Total Hosts:  $TOTAL"
echo "Passed:       $PASSED"
echo "Failed:       $FAILED"
echo "Success Rate: $((PASSED * 100 / TOTAL))%"
echo ""
echo "Detailed results: $SUMMARY_FILE"
echo "Individual results: $RESULTS_DIR/*.result"

if [[ $FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ All hosts passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${YELLOW}⚠ Some hosts failed. Check $SUMMARY_FILE for details.${NC}"
    exit 1
fi
