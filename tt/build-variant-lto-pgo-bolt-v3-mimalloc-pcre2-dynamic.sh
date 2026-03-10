#!/usr/bin/env bash
set -euox pipefail

source "$(dirname "$0")/build-lib.sh"

VARIANT_NAME="lto-pgo-bolt-v3-mimalloc-pcre2-dynamic"
DESCRIPTION="LTO + PGO + BOLT + x86-64-v3 + mimalloc (dynamic PCRE2, dynamic glibc)"
BUILD_TYPE="bolt"
TARGET="x86_64-unknown-linux-gnu"
PROFILE="release-bolt"
RUSTFLAGS="-C target-cpu=x86-64-v3"
FEATURES="pcre2"

build_variant "$VARIANT_NAME" "$DESCRIPTION" "$BUILD_TYPE" "$TARGET" "$PROFILE" "$RUSTFLAGS" "$FEATURES"
