#!/usr/bin/env bash
set -euox pipefail

source "$(dirname "$0")/build-lib.sh"

VARIANT_NAME="lto-pgo-bolt-mimalloc-pcre2-static"
DESCRIPTION="LTO + PGO + BOLT + mimalloc (static PCRE2, dynamic glibc)"
BUILD_TYPE="bolt"
TARGET="x86_64-unknown-linux-gnu"
PROFILE="release-bolt"
RUSTFLAGS=""
FEATURES="pcre2"

build_variant "$VARIANT_NAME" "$DESCRIPTION" "$BUILD_TYPE" "$TARGET" "$PROFILE" "$RUSTFLAGS" "$FEATURES"
