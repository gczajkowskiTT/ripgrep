#!/usr/bin/env bash
#
# build-bolt.sh - Build ripgrep with BOLT (Binary Optimization and Layout Tool)
#
# This script builds ripgrep with BOLT post-link optimization for maximum performance.
# BOLT reorders code layout based on execution profiles to improve cache locality.
#
# Expected performance gain: 5-10% on top of PGO optimization
#
# Usage:
#   ./build-bolt.sh [OPTIONS]
#
# Options:
#   --profile-method METHOD  Profiling method: instrumentation (default), perf, or cargo-pgo
#   --workload-dir DIR       Directory to use for profiling workloads (default: ../crates/)
#   --profile-runs N         Number of profiling runs to collect (default: 5)
#   --features FEATURES      Cargo features to enable (default: pcre2)
#   --skip-pgo              Skip PGO build (use existing binary)
#   --skip-profile          Skip profile collection (use existing profile data)
#   --clean                 Clean all build artifacts before starting
#   --help                  Show this help message
#
# Profile Methods:
#   instrumentation - Use BOLT's built-in instrumentation (no special permissions needed)
#   perf           - Use Linux perf tool (requires kernel.perf_event_paranoid <= 1)
#   cargo-pgo      - Use cargo-pgo tool (must be installed: cargo install cargo-pgo)
#
# Examples:
#   ./build-bolt.sh                                    # Use instrumentation (recommended)
#   ./build-bolt.sh --profile-method perf              # Use perf profiling
#   ./build-bolt.sh --profile-method cargo-pgo         # Use cargo-pgo
#   ./build-bolt.sh --workload-dir /large/codebase     # Custom workload
#   ./build-bolt.sh --profile-runs 10 --clean          # More profiling runs
#

set -euo pipefail

# Determine script and ripgrep root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RIPGREP_ROOT"

# Default configuration
SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
mkdir -p "$SCRATCH_DIR"
PROFILE_METHOD="${PROFILE_METHOD:-instrumentation}"
WORKLOAD_DIR="${WORKLOAD_DIR:-$RIPGREP_ROOT/crates/}"
PROFILE_RUNS="${PROFILE_RUNS:-5}"
FEATURES="${FEATURES:-pcre2}"
SKIP_PGO=0
SKIP_PROFILE=0
CLEAN_BUILD=0
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile-method)
            PROFILE_METHOD="$2"
            shift 2
            ;;
        --workload-dir)
            WORKLOAD_DIR="$2"
            shift 2
            ;;
        --profile-runs)
            PROFILE_RUNS="$2"
            shift 2
            ;;
        --features)
            FEATURES="$2"
            shift 2
            ;;
        --skip-pgo)
            SKIP_PGO=1
            shift
            ;;
        --skip-profile)
            SKIP_PROFILE=1
            shift
            ;;
        --clean)
            CLEAN_BUILD=1
            shift
            ;;
        --help)
            head -n 40 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

# Validate profile method
if [[ "$PROFILE_METHOD" != "instrumentation" && "$PROFILE_METHOD" != "perf" && "$PROFILE_METHOD" != "cargo-pgo" ]]; then
    echo -e "${RED}Error: Invalid profile method '$PROFILE_METHOD'${NC}"
    echo "Valid options: instrumentation, perf, cargo-pgo"
    exit 1
fi

# Verify workload directory exists
if [[ ! -d "$WORKLOAD_DIR" ]]; then
    echo -e "${RED}Error: Workload directory '$WORKLOAD_DIR' does not exist${NC}"
    echo "Please specify a valid directory with --workload-dir"
    exit 1
fi

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Ripgrep BOLT Optimization Build                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Profile method: $PROFILE_METHOD"
echo "Workload directory: $WORKLOAD_DIR"
echo "Profile runs: $PROFILE_RUNS"
echo "Features: $FEATURES"
echo ""

# Check for required tools based on profile method
echo -e "${BLUE}Checking required tools...${NC}"

if [[ "$PROFILE_METHOD" == "cargo-pgo" ]]; then
    if ! command -v cargo-pgo &> /dev/null; then
        echo -e "${RED}Error: cargo-pgo not found${NC}"
        echo "Install with: cargo install cargo-pgo"
        exit 1
    fi
    echo "  ✓ cargo-pgo: $(which cargo-pgo)"
else
    # For instrumentation and perf methods, we need BOLT tools
    if ! command -v llvm-bolt &> /dev/null; then
        echo -e "${RED}Error: BOLT tools must be available in PATH${NC}"
        echo "Make sure clang module is loaded: module load clang"
        exit 1
    fi
    echo "  ✓ llvm-bolt: $(which llvm-bolt)"

    if ! command -v perf2bolt &> /dev/null; then
        echo -e "${RED}Error: BOLT tools must be available in PATH${NC}"
        echo "Make sure clang module is loaded: module load clang"
        exit 1
    fi
    echo "  ✓ perf2bolt: $(which perf2bolt)"

    if [[ "$PROFILE_METHOD" == "perf" ]]; then
        if ! command -v perf &> /dev/null; then
            echo -e "${RED}Error: perf must be available in PATH${NC}"
            echo "Install with: sudo yum install perf"
            exit 1
        fi
        echo "  ✓ perf: $(which perf)"
    fi

    if ! command -v llvm-profdata &> /dev/null; then
        echo -e "${RED}Error: llvm-profdata must be available in PATH${NC}"
        echo "Install with: rustup component add llvm-tools-preview"
        exit 1
    fi
    echo "  ✓ llvm-profdata: $(which llvm-profdata)"
fi
echo ""

# Clean if requested
if [[ $CLEAN_BUILD -eq 1 ]]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    cargo clean
    rm -f perf.data perf.fdata
    rm -f $SCRATCH_DIR/prof.fdata $SCRATCH_DIR/prof.fdata.*
    echo ""
fi

# Function to run profiling workloads
run_workloads() {
    local binary=$1
    local run_num=$2

    case $((run_num % 5)) in
        0)
            "$binary" "fn " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
            ;;
        1)
            "$binary" "struct " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
            ;;
        2)
            "$binary" -i "error" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
            ;;
        3)
            "$binary" "TODO|FIXME" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
            ;;
        4)
            "$binary" -w "match" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
            ;;
    esac
}

#
# CARGO-PGO METHOD
#
if [[ "$PROFILE_METHOD" == "cargo-pgo" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Using cargo-pgo for BOLT optimization${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Step 1: Build with BOLT instrumentation using cargo-pgo
    echo -e "${BLUE}Step 1/3: Building instrumented binary with cargo-pgo...${NC}"

    if [[ $SKIP_PGO -eq 0 ]]; then
        cargo pgo bolt build --release --features "$FEATURES" --with-pgo
    else
        cargo pgo bolt build --release --features "$FEATURES"
    fi

    echo -e "${GREEN}✓ Instrumented binary built${NC}"
    echo ""

    # Step 2: Run profiling workloads
    if [[ $SKIP_PROFILE -eq 0 ]]; then
        echo -e "${BLUE}Step 2/3: Running profiling workloads...${NC}"

        # Find the instrumented binary
        INSTRUMENTED_BIN=$(find target -name "rg" -path "*/bolt-instrumented/*" | head -1)

        if [[ -z "$INSTRUMENTED_BIN" ]]; then
            echo -e "${RED}Error: Could not find instrumented binary${NC}"
            exit 1
        fi

        echo "Running $PROFILE_RUNS profiling workloads..."
        for i in $(seq 1 $PROFILE_RUNS); do
            echo "  Run $i/$PROFILE_RUNS..."
            run_workloads "$INSTRUMENTED_BIN" $i
        done

        echo -e "${GREEN}✓ Profiling completed${NC}"
        echo ""
    fi

    # Step 3: Optimize with BOLT
    echo -e "${BLUE}Step 3/3: Optimizing with BOLT...${NC}"

    if [[ $SKIP_PGO -eq 0 ]]; then
        cargo pgo bolt optimize --release --features "$FEATURES" --with-pgo
    else
        cargo pgo bolt optimize --release --features "$FEATURES"
    fi

    # Find the optimized binary
    BOLT_BINARY=$(find target -name "rg" -path "*/bolt-optimized/*" | head -1)

    if [[ -z "$BOLT_BINARY" ]]; then
        echo -e "${RED}Error: Could not find BOLT-optimized binary${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ BOLT optimization complete${NC}"
    echo ""

    # Install the binary
    echo -e "${BLUE}Installing BOLT-optimized binary...${NC}"
    mkdir -p "$INSTALL_DIR"
    cp "$BOLT_BINARY" "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic"
    chmod +x "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic"

    echo -e "${GREEN}✓ Installed: $INSTALL_DIR/rg-bolt${NC}"
    echo "  Size: $(du -h "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic" | cut -f1)"
    echo ""

#
# INSTRUMENTATION OR PERF METHOD
#
else
    # Step 1: Build PGO-optimized binary (base for BOLT)
    # Use release-bolt profile which preserves debug symbols needed by BOLT
    PGO_BINARY="target/release-bolt/rg"

    if [[ $SKIP_PGO -eq 0 ]]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Step 1/4: Building PGO-optimized binary...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Use the existing PGO build script with release-bolt profile
        if [[ -f "$SCRIPT_DIR/build-pgo.sh" ]]; then
            CARGO_PROFILE=release-bolt bash "$SCRIPT_DIR/build-pgo.sh" --workload-dir "$WORKLOAD_DIR" --features "$FEATURES"
        else
            echo -e "${RED}Error: build-pgo.sh not found${NC}"
            exit 1
        fi

        if [[ ! -f "$PGO_BINARY" ]]; then
            echo -e "${RED}Error: PGO binary not found at $PGO_BINARY${NC}"
            exit 1
        fi

        echo ""
        echo -e "${GREEN}✓ PGO binary built successfully${NC}"
        echo "  Location: $PGO_BINARY"
        echo "  Size: $(du -h $PGO_BINARY | cut -f1)"
        echo ""
    else
        echo -e "${YELLOW}Skipping PGO build (using existing binary)${NC}"
        if [[ ! -f "$PGO_BINARY" ]]; then
            echo -e "${RED}Error: PGO binary not found at $PGO_BINARY${NC}"
            exit 1
        fi
        echo ""
    fi

    #
    # INSTRUMENTATION METHOD
    #
    if [[ "$PROFILE_METHOD" == "instrumentation" ]]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Step 2/4: Creating instrumented binary with BOLT...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Use same directory as PGO_BINARY for instrumented binary
        PGO_DIR=$(dirname "$PGO_BINARY")
        INSTRUMENTED_BINARY="$PGO_DIR/rg-instrumented"
        mkdir -p "$PGO_DIR"

        llvm-bolt "$PGO_BINARY" \
            -instrument \
            -instrumentation-file=$SCRATCH_DIR/prof.fdata \
            -o "$INSTRUMENTED_BINARY"

        if [[ ! -f "$INSTRUMENTED_BINARY" ]]; then
            echo -e "${RED}Error: Failed to create instrumented binary${NC}"
            exit 1
        fi

        echo -e "${GREEN}✓ Instrumented binary created${NC}"
        echo "  Location: $INSTRUMENTED_BINARY"
        echo ""

        # Step 3: Run profiling workloads
        if [[ $SKIP_PROFILE -eq 0 ]]; then
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}Step 3/4: Running profiling workloads...${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            # Clean old profile data
            rm -f $SCRATCH_DIR/prof.fdata $SCRATCH_DIR/prof.fdata.*

            echo "Running $PROFILE_RUNS profiling workloads..."
            echo ""

            for i in $(seq 1 $PROFILE_RUNS); do
                echo "  Run $i/$PROFILE_RUNS..."
                run_workloads "$INSTRUMENTED_BINARY" $i
            done

            # Merge profile data if multiple files created
            if ls $SCRATCH_DIR/prof.fdata.* 1> /dev/null 2>&1; then
                echo ""
                echo "Merging profile data..."
                merge-fdata $SCRATCH_DIR/prof.fdata.* > $SCRATCH_DIR/prof.fdata
                rm -f $SCRATCH_DIR/prof.fdata.*
            fi

            if [[ ! -f $SCRATCH_DIR/prof.fdata ]]; then
                echo -e "${RED}Error: Failed to collect profile data${NC}"
                exit 1
            fi

            echo ""
            echo -e "${GREEN}✓ Profile data collected${NC}"
            echo "  Profile: $SCRATCH_DIR/prof.fdata ($(du -h $SCRATCH_DIR/prof.fdata | cut -f1))"
            echo ""
        else
            echo -e "${YELLOW}Skipping profile collection (using existing $SCRATCH_DIR/prof.fdata)${NC}"
            if [[ ! -f $SCRATCH_DIR/prof.fdata ]]; then
                echo -e "${RED}Error: $SCRATCH_DIR/prof.fdata not found${NC}"
                exit 1
            fi
            echo ""
        fi

        # Step 4: Optimize with BOLT
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Step 4/4: Optimizing with BOLT...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        BOLT_BINARY="$PGO_DIR/rg-lto-pgo-bolt-dynamic"
        rm -f "$BOLT_BINARY"

        echo "Running BOLT optimization..."
        echo ""

        llvm-bolt "$PGO_BINARY" \
            -o "$BOLT_BINARY" \
            -data=$SCRATCH_DIR/prof.fdata \
            -reorder-blocks=ext-tsp \
            -reorder-functions=hfsort+ \
            -split-functions=3 \
            -split-all-cold \
            -split-eh \
            -dyno-stats \
            -icf=1 \
            -use-gnu-stack \
            2>&1 | tee bolt-optimization.log

    #
    # PERF METHOD
    #
    elif [[ "$PROFILE_METHOD" == "perf" ]]; then
        # Use same directory as PGO_BINARY for BOLT outputs
        PGO_DIR=$(dirname "$PGO_BINARY")
        mkdir -p "$PGO_DIR"

        # Step 2: Collect execution profile with perf
        if [[ $SKIP_PROFILE -eq 0 ]]; then
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}Step 2/4: Collecting execution profile with perf...${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            # Remove old profile data
            rm -f perf.data perf.data.old

            echo "Running $PROFILE_RUNS profiling workloads..."
            echo ""

            # Collect multiple profiles for better coverage
            for i in $(seq 1 $PROFILE_RUNS); do
                echo "  Run $i/$PROFILE_RUNS..."

                # Run with different search patterns to get diverse profile
                case $((i % 5)) in
                    0)
                        perf record -e cycles:u -j any,u --append -o perf.data -- \
                            "$PGO_BINARY" "fn " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
                        ;;
                    1)
                        perf record -e cycles:u -j any,u --append -o perf.data -- \
                            "$PGO_BINARY" "struct " "$WORKLOAD_DIR" > /dev/null 2>&1 || true
                        ;;
                    2)
                        perf record -e cycles:u -j any,u --append -o perf.data -- \
                            "$PGO_BINARY" -i "error" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
                        ;;
                    3)
                        perf record -e cycles:u -j any,u --append -o perf.data -- \
                            "$PGO_BINARY" "TODO|FIXME" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
                        ;;
                    4)
                        perf record -e cycles:u -j any,u --append -o perf.data -- \
                            "$PGO_BINARY" -w "match" "$WORKLOAD_DIR" > /dev/null 2>&1 || true
                        ;;
                esac
            done

            if [[ ! -f perf.data ]]; then
                echo -e "${RED}Error: Failed to collect perf data${NC}"
                echo "This may be due to kernel.perf_event_paranoid restrictions."
                echo "Try: sudo sysctl -w kernel.perf_event_paranoid=1"
                echo "Or use: ./build-bolt.sh --profile-method instrumentation"
                exit 1
            fi

            echo ""
            echo -e "${GREEN}✓ Profile data collected${NC}"
            echo "  Profile: perf.data ($(du -h perf.data | cut -f1))"
            echo ""
        else
            echo -e "${YELLOW}Skipping profile collection (using existing perf.data)${NC}"
            if [[ ! -f perf.data ]]; then
                echo -e "${RED}Error: perf.data not found${NC}"
                exit 1
            fi
            echo ""
        fi

        # Step 3: Convert perf data to BOLT format
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Step 3/4: Converting perf data to BOLT format...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        rm -f perf.fdata

        perf2bolt -p perf.data -o perf.fdata "$PGO_BINARY"

        if [[ ! -f perf.fdata ]]; then
            echo -e "${RED}Error: Failed to convert perf data to BOLT format${NC}"
            exit 1
        fi

        echo ""
        echo -e "${GREEN}✓ BOLT profile data created${NC}"
        echo "  Profile: perf.fdata ($(du -h perf.fdata | cut -f1))"
        echo ""

        # Step 4: Optimize with BOLT
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Step 4/4: Optimizing with BOLT...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        BOLT_BINARY="$PGO_DIR/rg-lto-pgo-bolt-dynamic"
        rm -f "$BOLT_BINARY"

        echo "Running BOLT optimization..."
        echo ""

        llvm-bolt "$PGO_BINARY" \
            -o "$BOLT_BINARY" \
            -data=perf.fdata \
            -reorder-blocks=ext-tsp \
            -reorder-functions=hfsort+ \
            -split-functions=3 \
            -split-all-cold \
            -split-eh \
            -dyno-stats \
            -icf=1 \
            -use-gnu-stack \
            2>&1 | tee bolt-optimization.log
    fi

    echo ""

    if [[ ! -f "$BOLT_BINARY" ]]; then
        echo -e "${RED}Error: BOLT optimization failed${NC}"
        echo "Check bolt-optimization.log for details"
        exit 1
    fi

    echo -e "${GREEN}✓ BOLT optimization complete${NC}"
    echo ""

    # Compare sizes
    PGO_SIZE=$(stat -f%z "$PGO_BINARY" 2>/dev/null || stat -c%s "$PGO_BINARY" 2>/dev/null)
    BOLT_SIZE=$(stat -f%z "$BOLT_BINARY" 2>/dev/null || stat -c%s "$BOLT_BINARY" 2>/dev/null)

    echo "Binary comparison:"
    echo "  PGO:  $(du -h $PGO_BINARY | cut -f1)  ($PGO_SIZE bytes)"
    echo "  BOLT: $(du -h $BOLT_BINARY | cut -f1)  ($BOLT_SIZE bytes)"
    echo ""

    # Install BOLT binary
    echo -e "${BLUE}Installing BOLT-optimized binary...${NC}"
    mkdir -p "$INSTALL_DIR"
    cp "$BOLT_BINARY" "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic"
    chmod +x "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic"

    echo -e "${GREEN}✓ Installed: $INSTALL_DIR/rg-bolt${NC}"
    echo ""
fi

# Verify binary works
echo -e "${BLUE}Verifying BOLT-optimized binary...${NC}"
if "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic" --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Binary verification passed${NC}"
    echo ""
    "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic" --version | head -1
else
    echo -e "${RED}✗ Binary verification failed${NC}"
    exit 1
fi
echo ""

# Quick performance test
echo -e "${BLUE}Quick performance comparison...${NC}"
echo ""

if command -v hyperfine &> /dev/null && [[ -f "$PGO_BINARY" ]] && [[ "$PROFILE_METHOD" != "cargo-pgo" ]]; then
    echo "Testing with hyperfine (3 warmup, 5 runs)..."
    echo ""
    hyperfine --warmup 3 --runs 5 \
        --command-name "pgo" "$PGO_BINARY 'fn ' $WORKLOAD_DIR" \
        --command-name "bolt" "$INSTALL_DIR/rg-lto-pgo-bolt-dynamic 'fn ' $WORKLOAD_DIR" \
        2>&1 || true
else
    echo "hyperfine not found or cargo-pgo used, skipping performance comparison"
    echo "Install hyperfine with: cargo install hyperfine"
fi
echo ""

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD COMPLETE                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "BOLT-optimized binary installed:"
echo "  Location: $INSTALL_DIR/rg-lto-pgo-bolt-dynamic"
echo "  Size: $(du -h $INSTALL_DIR/rg-lto-pgo-bolt-dynamic | cut -f1)"
echo "  Method: $PROFILE_METHOD"
echo ""
echo "Usage:"
echo "  $INSTALL_DIR/rg-lto-pgo-bolt-dynamic \"pattern\" /path/to/search"
echo ""
if [[ "$PROFILE_METHOD" != "cargo-pgo" ]]; then
    echo "Files generated:"
    echo "  $BOLT_BINARY"
    if [[ "$PROFILE_METHOD" == "perf" ]]; then
        echo "  perf.data (profile data)"
        echo "  perf.fdata (BOLT profile)"
    else
        echo "  $SCRATCH_DIR/prof.fdata (BOLT profile)"
    fi
    echo "  bolt-optimization.log (BOLT output)"
    echo ""
fi
echo "Next steps:"
echo "  # Compare with other variants"
echo "  $SCRIPT_DIR/benchmark-quick.sh"
echo ""
echo "  # Or benchmark manually"
echo "  hyperfine --warmup 3 \\"
echo "    '$INSTALL_DIR/rg-lto-pgo-dynamic pattern $WORKLOAD_DIR' \\"
echo "    '$INSTALL_DIR/rg-lto-pgo-bolt-dynamic pattern $WORKLOAD_DIR'"
echo ""
