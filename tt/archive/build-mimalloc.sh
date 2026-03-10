#!/usr/bin/env bash
#
# build-mimalloc.sh - Build ripgrep with mimalloc allocator
#
# Builds both static and dynamic mimalloc variants based on LTO+PGO optimization.
# mimalloc is known for excellent single-threaded performance and low memory overhead.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

MIMALLOC_ROOT="/tools_soc/opensrc/mimalloc/2.1.7"
MIMALLOC_LIB="$MIMALLOC_ROOT/lib64"
MIMALLOC_LIB_STATIC="$MIMALLOC_LIB/mimalloc-2.1"
MIMALLOC_INCLUDE="$MIMALLOC_ROOT/include"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Building Ripgrep with mimalloc Allocator           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if mimalloc is available
if [[ ! -d "$MIMALLOC_ROOT" ]]; then
    echo -e "${RED}Error: mimalloc not found at $MIMALLOC_ROOT${NC}"
    exit 1
fi

echo "mimalloc location: $MIMALLOC_ROOT"
echo "mimalloc libraries:"
ls -lh "$MIMALLOC_LIB"/libmimalloc* 2>/dev/null || true
ls -lh "$MIMALLOC_LIB_STATIC"/libmimalloc* 2>/dev/null || true
echo ""

cd "$RIPGREP_ROOT"

# Determine linking mode
LINK_MODE="${LINK_MODE:-both}"  # both, static, or dynamic

build_variant() {
    local link_type=$1  # "static" or "dynamic"
    local output_name=$2

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building: $output_name ($link_type mimalloc)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Clean previous builds
    cargo clean

    if [[ "$link_type" == "static" ]]; then
        # Static linking with mimalloc
        export RUSTFLAGS="-C target-cpu=native -C link-arg=-L$MIMALLOC_LIB_STATIC -C link-arg=-lmimalloc -C link-arg=-lpthread"
        FEATURES="pcre2"
    else
        # Dynamic linking with mimalloc
        export RUSTFLAGS="-C target-cpu=native -C link-arg=-L$MIMALLOC_LIB -C link-arg=-lmimalloc -C link-arg=-Wl,-rpath,$MIMALLOC_LIB"
        FEATURES="pcre2"
    fi

    echo "Building with mimalloc ($link_type)..."
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

    # Check if mimalloc is linked
    echo "Checking mimalloc linkage:"
    if ldd "$INSTALL_DIR/$output_name" 2>/dev/null | grep -i mimalloc; then
        echo -e "${GREEN}✓ mimalloc dynamically linked${NC}"
    else
        echo -e "${YELLOW}Note: mimalloc may be statically linked or not detected by ldd${NC}"
    fi
    echo ""
}

# Build requested variants
if [[ "$LINK_MODE" == "static" ]] || [[ "$LINK_MODE" == "both" ]]; then
    build_variant "static" "rg-lto-pgo-mimalloc-static"
fi

if [[ "$LINK_MODE" == "dynamic" ]] || [[ "$LINK_MODE" == "both" ]]; then
    build_variant "dynamic" "rg-lto-pgo-mimalloc-dynamic"
fi

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD COMPLETE                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Binaries installed to: $INSTALL_DIR"
if [[ "$LINK_MODE" == "static" ]] || [[ "$LINK_MODE" == "both" ]]; then
    ls -lh "$INSTALL_DIR/rg-lto-pgo-mimalloc-static"
fi
if [[ "$LINK_MODE" == "dynamic" ]] || [[ "$LINK_MODE" == "both" ]]; then
    ls -lh "$INSTALL_DIR/rg-lto-pgo-mimalloc-dynamic"
fi
echo ""
