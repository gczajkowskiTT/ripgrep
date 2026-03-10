#!/usr/bin/env bash
#
# build-jemalloc.sh - Build ripgrep with jemalloc allocator
#
# Builds both static and dynamic jemalloc variants based on LTO+PGO optimization.
# jemalloc is known for good performance in multi-threaded workloads.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

JEMALLOC_ROOT="/tools_soc/opensrc/jemalloc/5.3.0"
JEMALLOC_LIB="$JEMALLOC_ROOT/lib"
JEMALLOC_INCLUDE="$JEMALLOC_ROOT/include"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Building Ripgrep with jemalloc Allocator           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if jemalloc is available
if [[ ! -d "$JEMALLOC_ROOT" ]]; then
    echo -e "${RED}Error: jemalloc not found at $JEMALLOC_ROOT${NC}"
    exit 1
fi

echo "jemalloc location: $JEMALLOC_ROOT"
echo "jemalloc libraries:"
ls -lh "$JEMALLOC_LIB"/libjemalloc* | head -5
echo ""

cd "$RIPGREP_ROOT"

# Determine linking mode and optimization level
LINK_MODE="${LINK_MODE:-both}"  # both, static, or dynamic
OPT_LEVEL="${OPT_LEVEL:-pgo}"   # pgo, pgo-v3, bolt, bolt-v3

build_variant() {
    local link_type=$1  # "static" or "dynamic"
    local output_name=$2

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building: $output_name ($link_type jemalloc)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Clean previous builds
    cargo clean

    # Set up environment for jemalloc
    export JEMALLOC_SYS_WITH_LG_PAGE=16

    if [[ "$link_type" == "static" ]]; then
        # Static linking with jemalloc
        export RUSTFLAGS="-C target-cpu=native -C link-arg=-L$JEMALLOC_LIB -C link-arg=-ljemalloc"
        FEATURES="pcre2"
    else
        # Dynamic linking with jemalloc
        export RUSTFLAGS="-C target-cpu=native -C link-arg=-L$JEMALLOC_LIB -C link-arg=-ljemalloc -C link-arg=-Wl,-rpath,$JEMALLOC_LIB"
        FEATURES="pcre2"
    fi

    echo "Building with jemalloc ($link_type)..."
    echo "RUSTFLAGS: $RUSTFLAGS"
    echo ""

    # Run PGO workflow
    echo "Step 1: Build for PGO profiling..."
    cd "$SCRIPT_DIR"
    CARGO_PROFILE=release-lto ./build-pgo.sh
    cd "$RIPGREP_ROOT"

    # The PGO script will create the optimized binary
    BINARY="target/release-lto/rg"

    if [[ ! -f "$BINARY" ]]; then
        echo -e "${RED}Error: Binary not found at $BINARY${NC}"
        exit 1
    fi

    # Install
    mkdir -p "$INSTALL_DIR"
    cp "$BINARY" "$INSTALL_DIR/$output_name"
    chmod +x "$INSTALL_DIR/$output_name"

    # Verify
    echo ""
    echo -e "${GREEN}Build complete!${NC}"
    echo "Binary: $INSTALL_DIR/$output_name"
    echo "Size: $(ls -lh "$INSTALL_DIR/$output_name" | awk '{print $5}')"
    "$INSTALL_DIR/$output_name" --version
    echo ""

    # Check if jemalloc is linked
    echo "Checking jemalloc linkage:"
    if ldd "$INSTALL_DIR/$output_name" 2>/dev/null | grep -i jemalloc; then
        echo -e "${GREEN}✓ jemalloc dynamically linked${NC}"
    else
        echo -e "${YELLOW}Note: jemalloc may be statically linked or not detected by ldd${NC}"
    fi
    echo ""
}

# Build requested variants
if [[ "$LINK_MODE" == "static" ]] || [[ "$LINK_MODE" == "both" ]]; then
    build_variant "static" "rg-lto-pgo-jemalloc-static"
fi

if [[ "$LINK_MODE" == "dynamic" ]] || [[ "$LINK_MODE" == "both" ]]; then
    build_variant "dynamic" "rg-lto-pgo-jemalloc-dynamic"
fi

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD COMPLETE                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Binaries installed to: $INSTALL_DIR"
if [[ "$LINK_MODE" == "static" ]] || [[ "$LINK_MODE" == "both" ]]; then
    ls -lh "$INSTALL_DIR/rg-lto-pgo-jemalloc-static"
fi
if [[ "$LINK_MODE" == "dynamic" ]] || [[ "$LINK_MODE" == "both" ]]; then
    ls -lh "$INSTALL_DIR/rg-lto-pgo-jemalloc-dynamic"
fi
echo ""
