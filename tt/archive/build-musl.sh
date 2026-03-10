#!/usr/bin/env bash
#
# build-musl.sh - Build static MUSL binary of ripgrep
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIPGREP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RIPGREP_ROOT"

SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"

# Set up musl toolchain
export PATH="$SCRATCH_DIR/x86_64-linux-musl-cross/bin:$PATH"
export CC_x86_64_unknown_linux_musl=x86_64-linux-musl-gcc
export AR_x86_64_unknown_linux_musl=x86_64-linux-musl-ar
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc

echo "Building static MUSL binary with release-lto profile..."
echo "Toolchain: $(which x86_64-linux-musl-gcc)"
echo ""

cargo build --target x86_64-unknown-linux-musl --profile release-lto --features pcre2

if [[ -f target/x86_64-unknown-linux-musl/release-lto/rg ]]; then
    echo ""
    echo "✓ Build successful!"
    echo "Binary: target/x86_64-unknown-linux-musl/release-lto/rg"
    echo "Size: $(du -h target/x86_64-unknown-linux-musl/release-lto/rg | cut -f1)"
    echo ""
    echo "Verifying static linking..."
    file target/x86_64-unknown-linux-musl/release-lto/rg
    echo ""
    ldd target/x86_64-unknown-linux-musl/release-lto/rg || echo "Not a dynamic executable (statically linked) ✓"
fi
