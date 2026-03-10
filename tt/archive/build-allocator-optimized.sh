#!/usr/bin/env bash
#
# build-allocator-optimized.sh - Build v3, BOLT, and BOLT+v3 variants for allocators
#
# Builds only the new optimization variants (skips base PGO which already exists)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

JEMALLOC_ROOT="/tools_soc/opensrc/jemalloc/5.3.0"
JEMALLOC_LIB="$JEMALLOC_ROOT/lib"
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
echo -e "${GREEN}║  Building Optimized Allocator Variants (v3/BOLT/BOLT+v3)    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd "$RIPGREP_ROOT"

# Build matrix: [allocator, link_type, opt_level, output_name]
# Skipping base PGO variants since they already exist
VARIANTS=(
    # jemalloc v3 variants
    "jemalloc|static|pgo-v3|rg-lto-pgo-v3-jemalloc-static"
    "jemalloc|dynamic|pgo-v3|rg-lto-pgo-v3-jemalloc-dynamic"
    # jemalloc BOLT variants
    "jemalloc|static|bolt|rg-lto-pgo-bolt-jemalloc-static"
    "jemalloc|dynamic|bolt|rg-lto-pgo-bolt-jemalloc-dynamic"
    # jemalloc BOLT+v3 variants
    "jemalloc|static|bolt-v3|rg-lto-pgo-bolt-v3-jemalloc-static"
    "jemalloc|dynamic|bolt-v3|rg-lto-pgo-bolt-v3-jemalloc-dynamic"
    # mimalloc v3 variants
    "mimalloc|static|pgo-v3|rg-lto-pgo-v3-mimalloc-static"
    "mimalloc|dynamic|pgo-v3|rg-lto-pgo-v3-mimalloc-dynamic"
    # mimalloc BOLT variants
    "mimalloc|static|bolt|rg-lto-pgo-bolt-mimalloc-static"
    "mimalloc|dynamic|bolt|rg-lto-pgo-bolt-mimalloc-dynamic"
    # mimalloc BOLT+v3 variants
    "mimalloc|static|bolt-v3|rg-lto-pgo-bolt-v3-mimalloc-static"
    "mimalloc|dynamic|bolt-v3|rg-lto-pgo-bolt-v3-mimalloc-dynamic"
)

VARIANT_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0

# Build each variant
for variant_info in "${VARIANTS[@]}"; do
    IFS='|' read -r allocator link_type opt_level output_name <<< "$variant_info"
    VARIANT_COUNT=$((VARIANT_COUNT + 1))

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building [$VARIANT_COUNT/12]: $output_name${NC}"
    echo -e "${BLUE}Allocator: $allocator | Link: $link_type | Optimization: $opt_level${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Clean previous builds
    cargo clean 2>/dev/null || true

    # Set up environment based on allocator
    if [[ "$allocator" == "jemalloc" ]]; then
        export JEMALLOC_SYS_WITH_LG_PAGE=16
        if [[ "$link_type" == "static" ]]; then
            ALLOC_FLAGS="-C link-arg=-L$JEMALLOC_LIB -C link-arg=-ljemalloc"
        else
            ALLOC_FLAGS="-C link-arg=-L$JEMALLOC_LIB -C link-arg=-ljemalloc -C link-arg=-Wl,-rpath,$JEMALLOC_LIB"
        fi
    else  # mimalloc
        if [[ "$link_type" == "static" ]]; then
            ALLOC_FLAGS="-C link-arg=-L$MIMALLOC_LIB_STATIC -C link-arg=-lmimalloc -C link-arg=-lpthread"
        else
            ALLOC_FLAGS="-C link-arg=-L$MIMALLOC_LIB -C link-arg=-lmimalloc -C link-arg=-Wl,-rpath,$MIMALLOC_LIB"
        fi
    fi

    # Build base RUSTFLAGS
    BASE_FLAGS="$ALLOC_FLAGS"

    # Add v3 flags if needed
    if [[ "$opt_level" == *"v3"* ]]; then
        BASE_FLAGS="$BASE_FLAGS -C target-cpu=x86-64-v3"
    else
        BASE_FLAGS="$BASE_FLAGS -C target-cpu=native"
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
        if CARGO_PROFILE=release-bolt ./build-bolt.sh 2>&1 | tail -20; then
            BINARY="$RIPGREP_ROOT/target/release-bolt/rg"
        else
            echo -e "${RED}BOLT build failed${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            continue
        fi
    else
        # PGO build
        cd "$SCRIPT_DIR"
        if CARGO_PROFILE=release-lto ./build-pgo.sh 2>&1 | tail -20; then
            BINARY="$RIPGREP_ROOT/target/release-lto/rg"
        else
            echo -e "${RED}PGO build failed${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            continue
        fi
    fi

    cd "$RIPGREP_ROOT"

    if [[ ! -f "$BINARY" ]]; then
        echo -e "${RED}Error: Binary not found at $BINARY${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    # Install
    mkdir -p "$INSTALL_DIR"
    cp "$BINARY" "$INSTALL_DIR/$output_name"
    chmod +x "$INSTALL_DIR/$output_name"

    # Verify
    echo ""
    echo -e "${GREEN}✓ Build complete!${NC}"
    echo "Binary: $INSTALL_DIR/$output_name"
    echo "Size: $(ls -lh "$INSTALL_DIR/$output_name" | awk '{print $5}')"
    if "$INSTALL_DIR/$output_name" --version | head -3; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}Binary verification failed${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
done

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD SUMMARY                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Successful: $SUCCESS_COUNT / $VARIANT_COUNT${NC}"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}✗ Failed: $FAIL_COUNT / $VARIANT_COUNT${NC}"
fi
echo ""
echo "All allocator variants in: $INSTALL_DIR"
ls -lh "$INSTALL_DIR"/rg-*-jemalloc-* "$INSTALL_DIR"/rg-*-mimalloc-* 2>/dev/null | head -20
echo ""
