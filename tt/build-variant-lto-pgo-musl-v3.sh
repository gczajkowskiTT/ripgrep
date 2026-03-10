#!/usr/bin/env bash
set -euox pipefail

source "$(dirname "$0")/build-lib.sh"

VARIANT_NAME="lto-pgo-musl-v3"
DESCRIPTION="LTO + PGO + MUSL + x86-64-v3 fully static"
BUILD_TYPE="pgo"
TARGET="x86_64-unknown-linux-musl"
PROFILE="release-lto"
RUSTFLAGS="-C target-cpu=x86-64-v3"
FEATURES="pcre2"

build_variant "$VARIANT_NAME" "$DESCRIPTION" "$BUILD_TYPE" "$TARGET" "$PROFILE" "$RUSTFLAGS" "$FEATURES"
