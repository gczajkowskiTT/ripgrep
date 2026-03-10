#!/usr/bin/env bash
#
# benchmark-linkers.sh - Compare different linkers for ripgrep builds
#
# Tests multiple linkers to see their impact on:
# - Build time (link time)
# - Binary size
# - Runtime performance
#
# Linkers tested:
# - Default (system ld via gcc)
# - lld (LLVM linker)
# - mold (multiple versions and optimizations)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
BUILD_INSTALL_DIR="${BUILD_INSTALL_DIR:-/proj_soc/user_dev/gczajkowski/bin}"
DATASET="${DATASET:-/proj_soc/user_dev/gczajkowski/chiplet-template}"
RESULTS_DIR="$SCRIPT_DIR/linker-benchmark-results"

# Build in /localdev/$USER for performance
SCRATCH_DIR="/localdev/$USER"
CARGO_BUILD_DIR="$SCRATCH_DIR/cargo-linker-benchmark"
export CARGO_TARGET_DIR="$CARGO_BUILD_DIR"
export TMPDIR="$SCRATCH_DIR/TMPDIR"

mkdir -p "$RESULTS_DIR"
mkdir -p "$CARGO_BUILD_DIR"
mkdir -p "$TMPDIR"

# Linkers to test
declare -A LINKERS=(
    ["default"]=""
    ["lld"]="/tools_soc/opensrc/clang/21.0.0/bin/ld.lld"
    ["mold-2.36.0"]="/tools_soc/opensrc/mold/2.36.0/bin/mold"
    ["mold-2.40.2"]="/tools_soc/opensrc/mold/2.40.2/bin/mold"
    ["mold-2.40.4-default"]="/tools_soc/opensrc/mold/2.40.4/default/bin/mold"
    ["mold-2.40.4-thinlto-pgo"]="/tools_soc/opensrc/mold/2.40.4/thinlto-pgo/bin/mold"
    ["mold-2.40.4-fulllto-pgo-bolt"]="/tools_soc/opensrc/mold/2.40.4/fulllto-pgo-bolt/bin/mold"
    ["mold-stable"]="/tools_soc/opensrc/mold/stable/bin/mold"
)

# Variants to test (representative sample)
VARIANTS=(
    "lto-thin"
    "lto-pgo-mimalloc-pcre2-dynamic"
    "lto-pgo-bolt-v3-mimalloc-pcre2-dynamic"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RIPGREP LINKER BENCHMARK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Testing ${#LINKERS[@]} linkers with ${#VARIANTS[@]} variant types"
echo "Build directory: $BUILD_INSTALL_DIR"
echo "Build location: $CARGO_TARGET_DIR"
echo "Temp directory: $TMPDIR"
echo "Dataset: $DATASET"
echo "Results: $RESULTS_DIR"
echo ""

# Build tracking
BUILD_RESULTS="$RESULTS_DIR/build-results.txt"
echo "Linker,Variant,BuildTime(s),BinarySize(bytes),Status" > "$BUILD_RESULTS"

# Runtime and memory tracking
MEMORY_RESULTS="$RESULTS_DIR/memory-results.txt"
echo "Linker,Variant,MaxRSS(KB),AvgRSS(KB),PageFaults,ContextSwitches" > "$MEMORY_RESULTS"

# Build function
build_with_linker() {
    local linker_name=$1
    local linker_path=$2
    local variant=$3

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Building: $variant with linker: $linker_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local build_script="$SCRIPT_DIR/build-variant-$variant.sh"
    if [[ ! -f "$build_script" ]]; then
        echo "ERROR: Build script not found: $build_script"
        echo "$linker_name,$variant,0,0,MISSING_SCRIPT" >> "$BUILD_RESULTS"
        return 1
    fi

    # Set linker environment variable
    export BUILD_INSTALL_DIR
    if [[ -n "$linker_path" ]]; then
        export BUILD_LINKER="$linker_path"
        echo "Using linker: $BUILD_LINKER"
    else
        unset BUILD_LINKER
        echo "Using default linker"
    fi

    # Clean previous build
    cd "$RIPGREP_ROOT"
    cargo clean 2>&1 || true

    # Time the build
    local start_time=$(date +%s)
    local binary_name="rg-${variant}-${linker_name}"

    # Temporarily override binary name for this build
    export BUILD_VARIANT_SUFFIX="-${linker_name}"

    if "$build_script" > "$RESULTS_DIR/build-${variant}-${linker_name}.log" 2>&1; then
        local end_time=$(date +%s)
        local build_time=$((end_time - start_time))

        # Check if binary exists (with or without linker suffix)
        local binary_path=""
        if [[ -f "$BUILD_INSTALL_DIR/rg-${variant}-${linker_name}" ]]; then
            binary_path="$BUILD_INSTALL_DIR/rg-${variant}-${linker_name}"
        elif [[ -f "$BUILD_INSTALL_DIR/rg-${variant}" ]]; then
            # Rename to include linker name
            mv "$BUILD_INSTALL_DIR/rg-${variant}" "$BUILD_INSTALL_DIR/rg-${variant}-${linker_name}"
            binary_path="$BUILD_INSTALL_DIR/rg-${variant}-${linker_name}"
        else
            echo "ERROR: Binary not found after build"
            echo "$linker_name,$variant,$build_time,0,BINARY_NOT_FOUND" >> "$BUILD_RESULTS"
            return 1
        fi

        local binary_size=$(stat -c%s "$binary_path")

        echo "SUCCESS: Built in ${build_time}s, size: $binary_size bytes"
        echo "$linker_name,$variant,$build_time,$binary_size,SUCCESS" >> "$BUILD_RESULTS"
    else
        local end_time=$(date +%s)
        local build_time=$((end_time - start_time))
        echo "ERROR: Build failed after ${build_time}s"
        echo "$linker_name,$variant,$build_time,0,BUILD_FAILED" >> "$BUILD_RESULTS"
        return 1
    fi

    unset BUILD_VARIANT_SUFFIX
}

# Build all combinations
echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 1: Building all variant/linker combinations"
echo "═══════════════════════════════════════════════════════════════"

total_builds=$((${#LINKERS[@]} * ${#VARIANTS[@]}))
current_build=0

for variant in "${VARIANTS[@]}"; do
    for linker_name in "${!LINKERS[@]}"; do
        current_build=$((current_build + 1))
        echo ""
        echo "Progress: $current_build/$total_builds"
        build_with_linker "$linker_name" "${LINKERS[$linker_name]}" "$variant" || true
    done
done

# Parse memory statistics from /usr/bin/time output
parse_memory_stats() {
    local time_output=$1
    local variant=$2
    local linker_name=$3

    # Extract max RSS (maximum resident set size) from each run
    local max_rss_values=$(grep "Maximum resident set size" "$time_output" | awk '{print $6}')
    local page_faults=$(grep "Major (requiring I/O) page faults" "$time_output" | awk '{print $6}')
    local ctx_switches=$(grep "Voluntary context switches" "$time_output" | awk '{print $5}')

    # Calculate average
    local max_rss_avg=$(echo "$max_rss_values" | awk '{s+=$1; c++} END {if(c>0) print s/c; else print 0}')
    local max_rss_max=$(echo "$max_rss_values" | sort -n | tail -1)
    local page_faults_avg=$(echo "$page_faults" | awk '{s+=$1; c++} END {if(c>0) print s/c; else print 0}')
    local ctx_switches_avg=$(echo "$ctx_switches" | awk '{s+=$1; c++} END {if(c>0) print s/c; else print 0}')

    # Save to results file
    echo "$linker_name,$variant,$max_rss_max,$max_rss_avg,$page_faults_avg,$ctx_switches_avg" >> "$MEMORY_RESULTS"
}

# Runtime benchmark function with memory tracking
benchmark_variant() {
    local variant=$1
    local linker_name=$2
    local pattern=$3
    local pattern_name=$4

    local binary="$BUILD_INSTALL_DIR/rg-${variant}-${linker_name}"
    if [[ ! -f "$binary" ]]; then
        echo "Binary not found: $binary"
        return 1
    fi

    local output_json="$RESULTS_DIR/runtime-${variant}-${linker_name}-${pattern_name}.json"
    local output_time="$RESULTS_DIR/memory-${variant}-${linker_name}-${pattern_name}.txt"

    echo "Benchmarking: rg-${variant}-${linker_name} with pattern: $pattern_name"

    # Run hyperfine for timing statistics
    hyperfine \
        --warmup 2 \
        --runs 5 \
        --export-json "$output_json" \
        "$binary --no-config --no-ignore $pattern '$DATASET'" \
        > "$RESULTS_DIR/runtime-${variant}-${linker_name}-${pattern_name}.log" 2>&1 || true

    # Run with /usr/bin/time for memory statistics (3 runs)
    echo "Collecting memory statistics..."
    for run in 1 2 3; do
        /usr/bin/time -v "$binary" --no-config --no-ignore "$pattern" "$DATASET" \
            > /dev/null 2>> "$output_time" || true
        echo "---" >> "$output_time"
    done

    # Parse and save memory statistics
    parse_memory_stats "$output_time" "$variant" "$linker_name"
}

# Runtime benchmarks
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 2: Runtime performance benchmarks"
echo "═══════════════════════════════════════════════════════════════"

# Test with a representative pattern
PATTERN="function"
PATTERN_NAME="literal"

for variant in "${VARIANTS[@]}"; do
    for linker_name in "${!LINKERS[@]}"; do
        benchmark_variant "$variant" "$linker_name" "$PATTERN" "$PATTERN_NAME" || true
    done
done

# Generate summary report
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 3: Generating summary report"
echo "═══════════════════════════════════════════════════════════════"

REPORT="$RESULTS_DIR/LINKER-BENCHMARK-REPORT.md"

cat > "$REPORT" << 'EOF'
# Ripgrep Linker Benchmark Report

## Objective

Compare different linkers to determine their impact on:
1. **Build Time** - How long linking takes
2. **Binary Size** - Size of the final executable
3. **Runtime Performance** - Speed of the resulting binary

## Tested Linkers

| Linker | Version | Path | Notes |
|--------|---------|------|-------|
| default | system ld | (gcc default) | Baseline |
| lld | 21.0.0 | /tools_soc/opensrc/clang/21.0.0/bin/lld | LLVM linker |
| mold | 2.36.0 | /tools_soc/opensrc/mold/2.36.0/bin/mold | Fast linker |
| mold | 2.40.2 | /tools_soc/opensrc/mold/2.40.2/bin/mold | Newer version |
| mold | 2.40.4-default | /tools_soc/opensrc/mold/2.40.4/default/bin/mold | Latest default |
| mold | 2.40.4-thinlto-pgo | /tools_soc/opensrc/mold/2.40.4/thinlto-pgo/bin/mold | ThinLTO+PGO optimized mold |
| mold | 2.40.4-fulllto-pgo-bolt | /tools_soc/opensrc/mold/2.40.4/fulllto-pgo-bolt/bin/mold | Fully optimized mold |
| mold | stable | /tools_soc/opensrc/mold/stable/bin/mold | Symlink to stable version |

## Test Variants

Three representative variants tested:
1. **lto-thin** - Simple LTO optimization (recommended baseline)
2. **lto-pgo-mimalloc-pcre2-dynamic** - PGO + allocator
3. **lto-pgo-bolt-v3-mimalloc-pcre2-dynamic** - Full optimization stack

## Build Results

EOF

# Add build results table
echo "" >> "$REPORT"
echo "### Build Time Comparison" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Linker | Variant | Build Time (s) | Binary Size | Status |" >> "$REPORT"
echo "|--------|---------|----------------|-------------|--------|" >> "$REPORT"

while IFS=, read -r linker variant build_time size status; do
    if [[ "$linker" != "Linker" ]]; then
        size_mb=$(awk "BEGIN {printf \"%.2f\", $size/1024/1024}")
        echo "| $linker | $variant | $build_time | ${size_mb}M | $status |" >> "$REPORT"
    fi
done < "$BUILD_RESULTS"

# Add runtime results if available
echo "" >> "$REPORT"
echo "### Runtime Performance" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Linker | Variant | Mean Time (s) | Std Dev (s) |" >> "$REPORT"
echo "|--------|---------|---------------|-------------|" >> "$REPORT"

for variant in "${VARIANTS[@]}"; do
    for linker_name in "${!LINKERS[@]}"; do
        json_file="$RESULTS_DIR/runtime-${variant}-${linker_name}-${PATTERN_NAME}.json"
        if [[ -f "$json_file" ]]; then
            mean_time=$(jq -r '.results[0].mean' "$json_file" 2>/dev/null || echo "N/A")
            stddev=$(jq -r '.results[0].stddev' "$json_file" 2>/dev/null || echo "N/A")
            if [[ "$mean_time" != "N/A" ]]; then
                echo "| $linker_name | $variant | $(printf "%.3f" $mean_time) | $(printf "%.3f" $stddev) |" >> "$REPORT"
            fi
        fi
    done
done

# Add memory results
echo "" >> "$REPORT"
echo "### Memory Usage" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Linker | Variant | Max RSS (MB) | Avg RSS (MB) | Page Faults | Context Switches |" >> "$REPORT"
echo "|--------|---------|--------------|--------------|-------------|------------------|" >> "$REPORT"

while IFS=, read -r linker variant max_rss avg_rss page_faults ctx_switches; do
    if [[ "$linker" != "Linker" ]]; then
        max_rss_mb=$(awk "BEGIN {printf \"%.2f\", $max_rss/1024}")
        avg_rss_mb=$(awk "BEGIN {printf \"%.2f\", $avg_rss/1024}")
        page_faults_int=$(printf "%.0f" "$page_faults")
        ctx_switches_int=$(printf "%.0f" "$ctx_switches")
        echo "| $linker | $variant | $max_rss_mb | $avg_rss_mb | $page_faults_int | $ctx_switches_int |" >> "$REPORT"
    fi
done < "$MEMORY_RESULTS"

cat >> "$REPORT" << 'EOF'

## Analysis

### Build Time Analysis

The linker has a direct impact on build time since it's the final phase of compilation:
- **Fastest Linker**: Check build results table above
- **Slowest Linker**: Check build results table above
- **Impact**: Difference between fastest and slowest linker

### Binary Size Impact

Some linkers may produce slightly different binary sizes due to:
- Different section alignment
- Debug information handling
- Symbol table organization

### Runtime Performance Impact

The linker should NOT significantly impact runtime performance for release builds since:
- Code generation happens before linking
- Optimizations are done by LLVM/Rust compiler
- Linker only arranges sections and resolves symbols

However, section layout can affect:
- CPU cache utilization
- Page faults
- Memory locality

### Memory Usage Analysis

Memory usage during execution is measured by:
- **Max RSS**: Maximum resident set size (peak memory usage)
- **Avg RSS**: Average resident set size across runs
- **Page Faults**: Major page faults requiring I/O
- **Context Switches**: Voluntary context switches

## Recommendations

Based on the complete results:

### For Development Builds
- **Fastest Link Time**: Choose the linker with shortest build time
- **Recommendation**: mold is typically 2-5x faster than ld

### For Production Builds
- **Best Performance**: Choose linker with best runtime + memory profile
- **Best Size**: Choose linker producing smallest binary
- **Balanced**: Consider build time vs runtime performance tradeoff

### Specific Recommendations
- **Fastest Build**: TBD (check Build Time Comparison table)
- **Smallest Binary**: TBD (check Binary Size column)
- **Best Runtime**: TBD (check Runtime Performance table)
- **Lowest Memory**: TBD (check Memory Usage table)
- **Overall Recommended**: TBD (balanced choice)

## Conclusion

### Build Environment
- Scratch directory: /localdev/$USER
- Cargo target: /localdev/$USER/cargo-linker-benchmark
- Temp directory: /localdev/$USER/TMPDIR

### Key Findings
1. **Build Speed**: [Analysis of linker build speed differences]
2. **Binary Size**: [Analysis of binary size variations]
3. **Runtime Impact**: [Analysis of runtime performance differences]
4. **Memory Impact**: [Analysis of memory usage patterns]

### Final Recommendation
[Select the best overall linker based on the specific use case and priorities]

EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  BENCHMARK COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Results saved to: $RESULTS_DIR"
echo "Report: $REPORT"
echo ""
echo "═══ Build Results ═══"
column -t -s',' "$BUILD_RESULTS" | head -30
echo ""
echo "═══ Memory Results ═══"
column -t -s',' "$MEMORY_RESULTS" | head -30
echo ""
echo "Full report available at: $REPORT"
echo ""
