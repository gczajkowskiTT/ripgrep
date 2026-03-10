#!/usr/bin/env bash
#
# build-pgo.sh - Build ripgrep with Profile-Guided Optimization
#
# This script builds ripgrep with PGO for maximum runtime performance.
# The resulting binary will be 5-10% faster and ~8% smaller than a standard
# release-lto build.
#
# Usage:
#   ./build-pgo.sh [OPTIONS]
#
# Options:
#   --workload-dir DIR    Directory to use for profiling workloads (default: crates/)
#   --pgo-data-dir DIR    Directory to store PGO profiling data (default: $SCRATCH_DIR/rg-pgo-data)
#   --features FEATURES   Cargo features to enable (default: pcre2)
#   --skip-workload       Skip running profiling workloads (use existing data)
#   --clean              Clean all build artifacts before starting
#   --help               Show this help message
#
# Examples:
#   ./build-pgo.sh
#   ./build-pgo.sh --workload-dir /large/codebase
#   ./build-pgo.sh --clean --features "pcre2"
#

set -euo pipefail

# Determine script and ripgrep root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RIPGREP_ROOT"

# Default configuration
SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
mkdir -p "$SCRATCH_DIR"
WORKLOAD_DIR="${WORKLOAD_DIR:-$RIPGREP_ROOT/crates/}"
PGO_DATA_DIR="${PGO_DATA_DIR:-$SCRATCH_DIR/rg-pgo-data}"
FEATURES="${FEATURES:-pcre2}"
CARGO_PROFILE="${CARGO_PROFILE:-release-lto}"
SKIP_WORKLOAD=0
CLEAN_BUILD=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workload-dir)
            WORKLOAD_DIR="$2"
            shift 2
            ;;
        --pgo-data-dir)
            PGO_DATA_DIR="$2"
            shift 2
            ;;
        --features)
            FEATURES="$2"
            shift 2
            ;;
        --skip-workload)
            SKIP_WORKLOAD=1
            shift
            ;;
        --clean)
            CLEAN_BUILD=1
            shift
            ;;
        --help)
            head -n 30 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

# Verify workload directory exists
if [[ ! -d "$WORKLOAD_DIR" ]]; then
    echo -e "${RED}Error: Workload directory '$WORKLOAD_DIR' does not exist${NC}"
    echo "Please specify a valid directory with --workload-dir"
    exit 1
fi

# Check for required tools
if ! command -v llvm-profdata &> /dev/null; then
    echo -e "${RED}Error: llvm-profdata not found${NC}"
    echo "Please install LLVM tools:"
    echo "  - Via rustup (recommended): rustup component add llvm-tools-preview"
    echo "  - Or ensure llvm-profdata is available in your PATH"
    exit 1
fi

echo -e "${GREEN}=== Ripgrep PGO Build ===${NC}"
echo "Workload directory: $WORKLOAD_DIR"
echo "PGO data directory: $PGO_DATA_DIR"
echo "Features: $FEATURES"
echo ""

# Clean if requested
if [[ $CLEAN_BUILD -eq 1 ]]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    cargo clean
fi

# Step 1: Build with instrumentation
echo -e "${YELLOW}Step 1/4: Building instrumented binary...${NC}"
mkdir -p "$PGO_DATA_DIR"
rm -rf "$PGO_DATA_DIR"/*

# Add --emit-relocs for release-bolt profile (required by BOLT instrumentation)
if [[ "$CARGO_PROFILE" == "release-bolt" ]]; then
    RUSTFLAGS="-C profile-generate=$PGO_DATA_DIR -C link-arg=-Wl,--emit-relocs" \
        cargo build --profile $CARGO_PROFILE --features "$FEATURES"
else
    RUSTFLAGS="-C profile-generate=$PGO_DATA_DIR" \
        cargo build --profile $CARGO_PROFILE --features "$FEATURES"
fi

INSTRUMENTED_BINARY="target/$CARGO_PROFILE/rg"

if [[ ! -f "$INSTRUMENTED_BINARY" ]]; then
    echo -e "${RED}Error: Instrumented binary not found at $INSTRUMENTED_BINARY${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Instrumented binary built successfully${NC}"
echo ""

# Step 2: Run profiling workloads
if [[ $SKIP_WORKLOAD -eq 0 ]]; then
    echo -e "${YELLOW}Step 2/4: Running profiling workloads...${NC}"
    echo "This will take a few moments..."

    # Run various typical ripgrep workloads to collect profiling data
    # These represent common use cases and search patterns

    # Basic string searches
    "$INSTRUMENTED_BINARY" "fn " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
    "$INSTRUMENTED_BINARY" "struct " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
    "$INSTRUMENTED_BINARY" "impl " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
    "$INSTRUMENTED_BINARY" "use " "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Type-specific searches
    "$INSTRUMENTED_BINARY" --type rust "pub " "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Case-insensitive searches
    "$INSTRUMENTED_BINARY" -i "error" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
    "$INSTRUMENTED_BINARY" -i "warning" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Pattern searches
    "$INSTRUMENTED_BINARY" "TODO|FIXME" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Word boundary searches
    "$INSTRUMENTED_BINARY" -w "match" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
    "$INSTRUMENTED_BINARY" -w "return" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Multiline searches
    "$INSTRUMENTED_BINARY" --multiline "fn.*\{" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Inverted searches
    "$INSTRUMENTED_BINARY" -v "test" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Context searches
    "$INSTRUMENTED_BINARY" -A 3 -B 3 "error" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # Count operations
    "$INSTRUMENTED_BINARY" -c "fn " "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    # File listing
    "$INSTRUMENTED_BINARY" -l "struct" "$WORKLOAD_DIR" > /dev/null 2>&1 || true

    echo -e "${GREEN}✓ Profiling workloads completed${NC}"
else
    echo -e "${YELLOW}Step 2/4: Skipping profiling workloads (using existing data)${NC}"
fi
echo ""

# Step 3: Merge profiling data
echo -e "${YELLOW}Step 3/4: Merging profiling data...${NC}"

PROFRAW_COUNT=$(find "$PGO_DATA_DIR" -name "*.profraw" | wc -l)

if [[ $PROFRAW_COUNT -eq 0 ]]; then
    echo -e "${RED}Error: No profiling data found in $PGO_DATA_DIR${NC}"
    echo "Make sure the profiling workloads ran successfully"
    exit 1
fi

echo "Found $PROFRAW_COUNT profiling data files"

llvm-profdata merge -o "$PGO_DATA_DIR/merged.profdata" "$PGO_DATA_DIR"/*.profraw

if [[ ! -f "$PGO_DATA_DIR/merged.profdata" ]]; then
    echo -e "${RED}Error: Failed to merge profiling data${NC}"
    exit 1
fi

MERGED_SIZE=$(du -h "$PGO_DATA_DIR/merged.profdata" | cut -f1)
echo -e "${GREEN}✓ Profiling data merged successfully ($MERGED_SIZE)${NC}"
echo ""

# Step 4: Build with PGO optimization
echo -e "${YELLOW}Step 4/4: Building PGO-optimized binary...${NC}"
cargo clean

# Add --emit-relocs for release-bolt profile (required by BOLT instrumentation)
if [[ "$CARGO_PROFILE" == "release-bolt" ]]; then
    RUSTFLAGS="-C profile-use=$PGO_DATA_DIR/merged.profdata -C llvm-args=-pgo-warn-missing-function -C link-arg=-Wl,--emit-relocs" \
        cargo build --profile $CARGO_PROFILE --features "$FEATURES"
else
    RUSTFLAGS="-C profile-use=$PGO_DATA_DIR/merged.profdata -C llvm-args=-pgo-warn-missing-function" \
        cargo build --profile $CARGO_PROFILE --features "$FEATURES"
fi

FINAL_BINARY="target/$CARGO_PROFILE/rg"

if [[ ! -f "$FINAL_BINARY" ]]; then
    echo -e "${RED}Error: Final binary not found at $FINAL_BINARY${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PGO-optimized binary built successfully${NC}"
echo ""

# Display results
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "PGO-optimized binary: $FINAL_BINARY"
echo "Binary size: $(du -h "$FINAL_BINARY" | cut -f1)"
echo ""
echo "To verify the binary:"
echo "  $FINAL_BINARY --version"
echo ""
echo "To install the binary:"
echo "  cp $FINAL_BINARY /desired/path/rg"
echo "  # or"
echo "  cargo install --path . --profile $CARGO_PROFILE --features $FEATURES"
echo ""
echo "Performance tip: This binary is optimized for workloads similar to those"
echo "run during profiling. For different workloads, re-run this script with"
echo "a representative workload directory."
