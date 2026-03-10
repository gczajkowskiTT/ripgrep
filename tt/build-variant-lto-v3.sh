#!/usr/bin/env bash
set -euox pipefail

source "$(dirname "$0")/build-lib.sh"

VARIANT_NAME="lto-v3"
DESCRIPTION="LTO fat optimization + x86-64-v3"
BUILD_TYPE="simple"
TARGET="x86_64-unknown-linux-gnu"
PROFILE="release-lto"
RUSTFLAGS="-C target-cpu=x86-64-v3"
FEATURES="pcre2"

build_variant "$VARIANT_NAME" "$DESCRIPTION" "$BUILD_TYPE" "$TARGET" "$PROFILE" "$RUSTFLAGS" "$FEATURES"
