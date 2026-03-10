#!/usr/bin/env bash
#
# build-jemalloc-all.sh - Build all jemalloc variants (PGO, v3, BOLT, BOLT+v3)
#
# Builds all combinations of jemalloc allocator variants with different optimizations.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

JEMALLOC_ROOT="/tools_soc/opensrc/jemalloc/5.3.0"
JEMALLOC_LIB="$JEMALLOC_ROOT/lib"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Building All Jemalloc Variants (PGO/v3/BOLT)            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if jemalloc is available
if [[ ! -d "$JEMALLOC_ROOT" ]]; then
    echo -e "${RED}Error: jemalloc not found at $JEMALLOC_ROOT${NC}"
    exit 1
fi

cd "$RIPGREP_ROOT"

# Build matrix: [link_type, opt_level, output_suffix]
VARIANTS=(
    "static|pgo|rg-lto-pgo-jemalloc-static"
    "dynamic|pgo|rg-lto-pgo-jemalloc-dynamic"
    "static|pgo-v3|rg-lto-pgo-v3-jemalloc-static"
    "dynamic|pgo-v3|rg-lto-pgo-v3-jemalloc-dynamic"
    "static|bolt|rg-lto-pgo-bolt-jemalloc-static"
    "dynamic|bolt|rg-lto-pgo-bolt-jemalloc-dynamic"
    "static|bolt-v3|rg-lto-pgo-bolt-v3-jemalloc-static"
    "dynamic|bolt-v3|rg-lto-pgo-bolt-v3-jemalloc-dynamic"
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

    # Set up environment for jemalloc
    export JEMALLOC_SYS_WITH_LG_PAGE=16

    # Build RUSTFLAGS based on link type and optimization
    BASE_FLAGS="-C target-cpu=native -C link-arg=-L$JEMALLOC_LIB -C link-arg=-ljemalloc"

    if [[ "$link_type" == "dynamic" ]]; then
        BASE_FLAGS="$BASE_FLAGS -C link-arg=-Wl,-rpath,$JEMALLOC_LIB"
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
ls -lh "$INSTALL_DIR"/rg-*-jemalloc-*
echo ""
