#!/usr/bin/env bash
#
# quick-test-hosts.sh - Quick test of PGO binary on sample hosts
#

set -uo pipefail

PGO_BINARY="/proj_soc/user_dev/gczajkowski/bin/rg"

# Sample of hosts to test quickly
HOSTS=(
    soc-c-02 soc-c-03 soc-c-05 soc-c-10
    soc-l-01 soc-l-02
    soc-zebu-01
)

echo "Quick testing PGO binary on sample hosts..."
echo ""

PASSED=0
FAILED=0

for host in "${HOSTS[@]}"; do
    echo -n "Testing $host... "

    result=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
        "2>/dev/null; $PGO_BINARY --version 2>&1 && echo '---' && $PGO_BINARY 'test' /etc/passwd 2>&1 | head -2" 2>&1)

    if [[ $? -eq 0 ]] && echo "$result" | grep -q "ripgrep"; then
        echo "✓ PASSED"
        ((PASSED++))
    else
        echo "✗ FAILED or UNREACHABLE"
        echo "  Error: $result" | head -2
        ((FAILED++))
    fi
done

echo ""
echo "Results: $PASSED passed, $FAILED failed"
