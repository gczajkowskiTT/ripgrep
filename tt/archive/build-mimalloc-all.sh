#!/usr/bin/env bash
#
# build-mimalloc-all.sh - Build all mimalloc variants (PGO, v3, BOLT, BOLT+v3)
#
# Builds all combinations of mimalloc allocator variants with different optimizations.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

MIMALLOC_ROOT="/tools_soc/opensrc/mimalloc/2.1.7"
MIMALLOC_LIB="$MIMALLOC_ROOT/lib64"
MIMALLOC_LIB_STATIC="$MIMALLOC_LIB/mimalloc-2.1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Building All Mimalloc Variants (PGO/v3/BOLT)            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if mimalloc is available
if [[ ! -d "$MIMALLOC_ROOT" ]]; then
    echo -e "${RED}Error: mimalloc not found at $MIMALLOC_ROOT${NC}"
    exit 1
fi

cd "$RIPGREP_ROOT"

# Build matrix: [link_type, opt_level, output_suffix]
VARIANTS=(
    "static|pgo|rg-lto-pgo-mimalloc-static"
    "dynamic|pgo|rg-lto-pgo-mimalloc-dynamic"
    "static|pgo-v3|rg-lto-pgo-v3-mimalloc-static"
    "dynamic|pgo-v3|rg-lto-pgo-v3-mimalloc-dynamic"
    "static|bolt|rg-lto-pgo-bolt-mimalloc-static"
    "dynamic|bolt|rg-lto-pgo-bolt-mimalloc-dynamic"
    "static|bolt-v3|rg-lto-pgo-bolt-v3-mimalloc-static"
    "dynamic|bolt-v3|rg-lto-pgo-bolt-v3-mimalloc-dynamic"
)

# Build each variant
for variant_info in "${VARIANTS[@]}"; do
    IFS='|' read -r link_type opt_level output_name <<< "$variant_info"

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building: $output_name${NC}"
    echo -e "${BLUE}Link: $link_type | Optimization: $opt_level${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Clean previous builds
    cargo clean

    # Build RUSTFLAGS based on link type and optimization
    if [[ "$link_type" == "static" ]]; then
        BASE_FLAGS="-C target-cpu=native -C link-arg=-L$MIMALLOC_LIB_STATIC -C link-arg=-lmimalloc -C link-arg=-lpthread"
    else
        BASE_FLAGS="-C target-cpu=native -C link-arg=-L$MIMALLOC_LIB -C link-arg=-lmimalloc -C link-arg=-Wl,-rpath,$MIMALLOC_LIB"
    fi

    # Add v3 flags if needed
    if [[ "$opt_level" == *"v3"* ]]; then
        BASE_FLAGS="$BASE_FLAGS -C target-cpu=x86-64-v3"
    fi

    # Add BOLT flags if needed
    if [[ "$opt_level" == "bolt"* ]]; then
        BASE_FLAGS="$BASE_FLAGS -C link-arg=-Wl,--emit-relocs"
    fi

    export RUSTFLAGS="$BASE_FLAGS"
    export FEATURES="pcre2"

    echo "RUSTFLAGS: $RUSTFLAGS"
    echo ""

    # Build based on optimization level
    if [[ "$opt_level" == "bolt"* ]]; then
        # BOLT build
        cd "$SCRIPT_DIR"
        CARGO_PROFILE=release-bolt ./build-bolt.sh
        BINARY="$RIPGREP_ROOT/target/release-bolt/rg"
    else
        # PGO build
        cd "$SCRIPT_DIR"
        if [[ "$opt_level" == *"v3"* ]]; then
            CARGO_PROFILE=release-lto ./build-pgo.sh
        else
            CARGO_PROFILE=release-lto ./build-pgo.sh
        fi
        BINARY="$RIPGREP_ROOT/target/release-lto/rg"
    fi

    cd "$RIPGREP_ROOT"

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
    "$INSTALL_DIR/$output_name" --version | head -3
    echo ""
done

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ALL BUILDS COMPLETE                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Binaries installed to: $INSTALL_DIR"
ls -lh "$INSTALL_DIR"/rg-*-mimalloc-*
echo ""
