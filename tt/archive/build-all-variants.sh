#!/usr/bin/env bash
#
# build-all-variants.sh - Build all ripgrep variants for benchmarking
#
# This script builds multiple variants of ripgrep for comparison:
# 1. Standard release
# 2. Release-LTO
# 3. PGO optimized
# 4. MUSL static
# 5. PGO + x86-64-v3
# 6. MUSL + x86-64-v3
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RIPGREP_ROOT"

SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
mkdir -p "$SCRATCH_DIR"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"
PGO_DATA_DIR="$SCRATCH_DIR/rg-pgo-variants-data"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Building All Ripgrep Variants for Benchmarking          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Install directory: $INSTALL_DIR"
echo ""

# Function to build and install a variant
build_variant() {
    local name=$1
    local target=$2
    local profile=$3
    local features=$4
    local extra_flags=$5
    local install_name=$6

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building: $name${NC}"
    echo "Target: $target"
    echo "Profile: $profile"
    echo "Features: $features"
    echo "Extra flags: $extra_flags"
    echo ""

    # Clean previous build
    cargo clean -q

    # Build
    local build_start=$(date +%s)
    if [[ -n "$extra_flags" ]]; then
        eval "RUSTFLAGS=\"$extra_flags\" cargo build --target $target --profile $profile --features $features -q"
    else
        cargo build --target $target --profile $profile --features $features -q
    fi
    local build_end=$(date +%s)
    local build_time=$((build_end - build_start))

    # Determine binary location
    local binary_path="target/$target/$profile/rg"

    if [[ ! -f "$binary_path" ]]; then
        echo -e "${RED}✗ Build failed - binary not found at $binary_path${NC}"
        return 1
    fi

    # Get binary size
    local size=$(du -h "$binary_path" | cut -f1)

    # Install
    cp "$binary_path" "$INSTALL_DIR/$install_name"
    chmod +x "$INSTALL_DIR/$install_name"

    echo -e "${GREEN}✓ Built successfully${NC}"
    echo "  Build time: ${build_time}s"
    echo "  Binary size: $size"
    echo "  Installed as: $INSTALL_DIR/$install_name"
    echo ""
}

# 1. Standard Release Build
build_variant \
    "Standard Release" \
    "x86_64-unknown-linux-gnu" \
    "release" \
    "pcre2" \
    "" \
    "rg-baseline"

# 2. Release-LTO Build
build_variant \
    "Release-LTO" \
    "x86_64-unknown-linux-gnu" \
    "release-lto" \
    "pcre2" \
    "" \
    "rg-lto"

# 3. PGO Optimized Build
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Building: PGO Optimized${NC}"
echo ""

# PGO Step 1: Instrumented build
echo "Step 1/3: Building instrumented binary..."
cargo clean -q
mkdir -p "$PGO_DATA_DIR"
rm -rf "$PGO_DATA_DIR"/*

RUSTFLAGS="-C profile-generate=$PGO_DATA_DIR" \
    cargo build --profile release-lto --features pcre2 -q

# PGO Step 2: Run profiling workloads
echo "Step 2/3: Collecting profiling data..."
./target/release-lto/rg "fn " crates/ > /dev/null 2>&1 || true
./target/release-lto/rg "struct " crates/ > /dev/null 2>&1 || true
./target/release-lto/rg "impl " crates/ > /dev/null 2>&1 || true
./target/release-lto/rg -i "error" crates/ > /dev/null 2>&1 || true
./target/release-lto/rg "TODO|FIXME" crates/ > /dev/null 2>&1 || true

# PGO Step 3: Merge profiling data
echo "Step 3/3: Building PGO-optimized binary..."
llvm-profdata merge -o "$PGO_DATA_DIR/merged.profdata" "$PGO_DATA_DIR"/*.profraw

cargo clean -q
RUSTFLAGS="-C profile-use=$PGO_DATA_DIR/merged.profdata -C llvm-args=-pgo-warn-missing-function" \
    cargo build --profile release-lto --features pcre2 -q

cp target/release-lto/rg "$INSTALL_DIR/rg-lto-pgo-dynamic"
chmod +x "$INSTALL_DIR/rg-lto-pgo-dynamic"

size=$(du -h target/release-lto/rg | cut -f1)
echo -e "${GREEN}✓ Built successfully${NC}"
echo "  Binary size: $size"
echo "  Installed as: $INSTALL_DIR/rg-lto-pgo-dynamic"
echo ""

# 4. MUSL Static Build
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Building: MUSL Static${NC}"
echo ""

cargo clean -q
export PATH="$SCRATCH_DIR/x86_64-linux-musl-cross/bin:$PATH"
export CC_x86_64_unknown_linux_musl=x86_64-linux-musl-gcc
export AR_x86_64_unknown_linux_musl=x86_64-linux-musl-ar
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc

cargo build --target x86_64-unknown-linux-musl --profile release-lto --features pcre2 -q

cp target/x86_64-unknown-linux-musl/release-lto/rg "$INSTALL_DIR/rg-lto-musl"
chmod +x "$INSTALL_DIR/rg-lto-musl"

size=$(du -h target/x86_64-unknown-linux-musl/release-lto/rg | cut -f1)
echo -e "${GREEN}✓ Built successfully${NC}"
echo "  Binary size: $size"
echo "  Installed as: $INSTALL_DIR/rg-lto-musl"
echo ""

# 5. PGO + x86-64-v3
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Building: PGO + x86-64-v3${NC}"
echo ""

# PGO v3 Step 1: Instrumented build with v3
echo "Step 1/3: Building instrumented binary with x86-64-v3..."
cargo clean -q
rm -rf "$PGO_DATA_DIR"/*

RUSTFLAGS="-C profile-generate=$PGO_DATA_DIR -C target-cpu=x86-64-v3" \
    cargo build --profile release-lto --features pcre2 -q

# PGO v3 Step 2: Run profiling workloads
echo "Step 2/3: Collecting profiling data..."
./target/release-lto/rg "fn " crates/ > /dev/null 2>&1 || true
./target/release-lto/rg "struct " crates/ > /dev/null 2>&1 || true
./target/release-lto/rg "impl " crates/ > /dev/null 2>&1 || true

# PGO v3 Step 3: Merge and build
echo "Step 3/3: Building PGO + v3 optimized binary..."
llvm-profdata merge -o "$PGO_DATA_DIR/merged.profdata" "$PGO_DATA_DIR"/*.profraw

cargo clean -q
RUSTFLAGS="-C profile-use=$PGO_DATA_DIR/merged.profdata -C llvm-args=-pgo-warn-missing-function -C target-cpu=x86-64-v3" \
    cargo build --profile release-lto --features pcre2 -q

cp target/release-lto/rg "$INSTALL_DIR/rg-lto-pgo-v3-dynamic"
chmod +x "$INSTALL_DIR/rg-lto-pgo-v3-dynamic"

size=$(du -h target/release-lto/rg | cut -f1)
echo -e "${GREEN}✓ Built successfully${NC}"
echo "  Binary size: $size"
echo "  Installed as: $INSTALL_DIR/rg-lto-pgo-v3-dynamic"
echo ""

# 6. MUSL + x86-64-v3
build_variant \
    "MUSL Static + x86-64-v3" \
    "x86_64-unknown-linux-musl" \
    "release-lto" \
    "pcre2" \
    "-C target-cpu=x86-64-v3" \
    "rg-musl-v3"

# Summary
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD SUMMARY                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "All variants built and installed to: $INSTALL_DIR"
echo ""
ls -lh "$INSTALL_DIR"/rg-* | awk '{print $9, "-", $5}'
echo ""
echo "Variants:"
echo "  rg-baseline    - Standard release build"
echo "  rg-lto         - Release with LTO"
echo "  rg-pgo         - PGO optimized"
echo "  rg-musl        - Static MUSL binary"
echo "  rg-pgo-v3      - PGO + x86-64-v3 optimizations"
echo "  rg-musl-v3     - Static MUSL + x86-64-v3"
echo ""
echo "Ready for benchmarking with hyperfine!"
