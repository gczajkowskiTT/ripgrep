#!/usr/bin/env bash
#
# build-bolt-pcre2-jit.sh - Build ripgrep with LTO+PGO+BOLT using custom PCRE2 with JIT
#
# This script builds ripgrep with the full optimization stack (LTO+PGO+BOLT)
# using a custom PCRE2 installation at /tools_soc/opensrc/pcre2/10.45/
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RIPGREP_ROOT"

SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
mkdir -p "$SCRATCH_DIR"

# Custom PCRE2 installation
PCRE2_ROOT="/tools_soc/opensrc/pcre2/10.45"
export PCRE2_SYS_STATIC=1
export PKG_CONFIG_PATH="$PCRE2_ROOT/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export PCRE2_LIB_DIR="$PCRE2_ROOT/lib"
export PCRE2_INCLUDE_DIR="$PCRE2_ROOT/include"

# Verify PCRE2 installation
if [[ ! -f "$PCRE2_ROOT/lib/libpcre2-8.a" ]]; then
    echo "Error: PCRE2 static library not found at $PCRE2_ROOT/lib/libpcre2-8.a"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Ripgrep LTO+PGO+BOLT Build with Custom PCRE2 (JIT)         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "PCRE2: $PCRE2_ROOT"
echo "PCRE2 version: $($PCRE2_ROOT/bin/pcre2-config --version)"
echo ""

# Clean previous build
echo "Cleaning previous build artifacts..."
cargo clean --profile release-bolt
rm -rf "$SCRATCH_DIR/rg-pgo-data" "$SCRATCH_DIR/prof.fdata" "$SCRATCH_DIR/prof.fdata.*"
echo ""

# Build with full optimization stack
echo "Building with LTO+PGO+BOLT optimization..."
echo ""

CARGO_PROFILE=release-bolt "$SCRIPT_DIR/build-bolt.sh" \
    --workload-dir "$RIPGREP_ROOT/crates/" \
    --features pcre2

# Install with different name
FINAL_BINARY="target/release-bolt/rg-lto-pgo-bolt-dynamic"
INSTALL_DIR="/proj_soc/user_dev/gczajkowski/bin"

if [[ -f "$FINAL_BINARY" ]]; then
    echo ""
    echo "Installing as rg-lto-pgo-bolt-static-pcre2..."
    cp "$FINAL_BINARY" "$INSTALL_DIR/rg-lto-pgo-bolt-static-pcre2"
    chmod +x "$INSTALL_DIR/rg-lto-pgo-bolt-static-pcre2"
    
    echo "✓ Installed: $INSTALL_DIR/rg-lto-pgo-bolt-static-pcre2"
    echo "  Size: $(du -h "$INSTALL_DIR/rg-lto-pgo-bolt-static-pcre2" | cut -f1)"
    echo ""
    
    echo "Verifying PCRE2 JIT..."
    "$INSTALL_DIR/rg-lto-pgo-bolt-static-pcre2" --version
    echo ""
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    BUILD COMPLETE                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Binary: $INSTALL_DIR/rg-lto-pgo-bolt-static-pcre2"
    echo "Optimizations: LTO + PGO + BOLT"
    echo "PCRE2: Static link with JIT from $PCRE2_ROOT"
else
    echo "Error: Build failed - binary not found at $FINAL_BINARY"
    exit 1
fi
