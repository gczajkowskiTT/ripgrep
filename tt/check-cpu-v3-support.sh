#!/usr/bin/env bash
#
# check-cpu-v3-support.sh - Check if all hosts support x86-64-v3
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/cpu-v3-results"
mkdir -p "$RESULTS_DIR"

# All hosts
HOSTS=(
    soc-c-02 soc-c-03 soc-c-04 soc-c-05 soc-c-06 soc-c-07 soc-c-08 soc-c-09
    soc-c-12 soc-c-13 soc-c-14 soc-c-15 soc-c-16 soc-c-17 soc-c-18 soc-c-19
    soc-c-20 soc-c-21 soc-c-22 soc-c-23 soc-c-24 soc-c-25 soc-c-26 soc-c-27
    soc-c-28 soc-c-29 soc-c-30 soc-c-31 soc-c-32
    soc-l-01 soc-l-02 soc-l-03 soc-l-04 soc-l-05 soc-l-06 soc-l-07 soc-l-09
    soc-l-10 soc-l-11 soc-l-12
    soc-zebu-01 soc-zebu-02 soc-zebu-03 soc-zebu-04
)

echo "Checking x86-64-v3 CPU feature support on all hosts..."
echo ""

# x86-64-v3 requirements (microarchitecture level from 2015+):
# - AVX2, BMI2, FMA, LZCNT, MOVBE, XSAVE
V3_FEATURES=("avx2" "bmi2" "fma" "lzcnt" "movbe" "xsave")

check_host() {
    local host=$1
    local result_file="$RESULTS_DIR/${host}.cpu"

    {
        # Get CPU model
        cpu_model=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
            "grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs" 2>/dev/null)

        if [[ -z "$cpu_model" ]]; then
            echo "HOST: $host"
            echo "STATUS: UNREACHABLE"
            exit 1
        fi

        # Get CPU flags
        cpu_flags=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "$host" \
            "grep 'flags' /proc/cpuinfo 2>/dev/null | head -1" 2>/dev/null)

        # Check for required features
        missing_features=()
        has_all=true

        for feature in "${V3_FEATURES[@]}"; do
            if ! echo "$cpu_flags" | grep -qw "$feature"; then
                missing_features+=("$feature")
                has_all=false
            fi
        done

        echo "HOST: $host"
        echo "CPU: $cpu_model"

        if $has_all; then
            echo "V3_SUPPORT: YES"
            echo "FEATURES: All x86-64-v3 features present"
        else
            echo "V3_SUPPORT: NO"
            echo "MISSING: ${missing_features[*]}"
        fi

    } > "$result_file" 2>&1
}

export -f check_host
export RESULTS_DIR
export V3_FEATURES

# Run checks in parallel
printf '%s\n' "${HOSTS[@]}" | xargs -n 1 -P 20 -I {} bash -c 'check_host "$@"' _ {}

echo "Processing results..."
echo ""

# Analyze results
V3_SUPPORTED=0
V3_NOT_SUPPORTED=0
UNREACHABLE=0

declare -A cpu_types

for host in "${HOSTS[@]}"; do
    result_file="$RESULTS_DIR/${host}.cpu"

    if [[ -f "$result_file" ]]; then
        status=$(grep "^V3_SUPPORT:" "$result_file" 2>/dev/null | cut -d' ' -f2)
        cpu=$(grep "^CPU:" "$result_file" 2>/dev/null | cut -d' ' -f2-)

        if [[ "$status" == "YES" ]]; then
            echo "✓ $host: x86-64-v3 SUPPORTED ($cpu)"
            ((V3_SUPPORTED++))
            cpu_types["$cpu"]=$((${cpu_types["$cpu"]:-0} + 1))
        elif [[ "$status" == "NO" ]]; then
            missing=$(grep "^MISSING:" "$result_file" | cut -d' ' -f2-)
            echo "✗ $host: x86-64-v3 NOT SUPPORTED (missing: $missing)"
            echo "  CPU: $cpu"
            ((V3_NOT_SUPPORTED++))
        else
            echo "? $host: UNREACHABLE"
            ((UNREACHABLE++))
        fi
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           x86-64-v3 Compatibility Summary                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "x86-64-v3 Supported:     $V3_SUPPORTED"
echo "x86-64-v3 NOT Supported: $V3_NOT_SUPPORTED"
echo "Unreachable:             $UNREACHABLE"
echo ""

if [[ $V3_NOT_SUPPORTED -eq 0 ]] && [[ $V3_SUPPORTED -gt 0 ]]; then
    echo "✓ ALL reachable hosts support x86-64-v3!"
    echo "  Safe to enable x86-64-v3 optimizations."
    echo ""
    echo "CPU types found:"
    for cpu in "${!cpu_types[@]}"; do
        echo "  - $cpu (${cpu_types[$cpu]} hosts)"
    done
elif [[ $V3_NOT_SUPPORTED -gt 0 ]]; then
    echo "⚠ Some hosts do NOT support x86-64-v3"
    echo "  Do NOT enable x86-64-v3 optimizations."
else
    echo "? Unable to determine support (check connectivity)"
fi

echo ""
echo "Detailed results: $RESULTS_DIR/*.cpu"
