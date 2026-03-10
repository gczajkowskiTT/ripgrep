#!/usr/bin/env bash
set -euox pipefail

source "$(dirname "$0")/build-lib.sh"

VARIANT_NAME="lto-thin"
DESCRIPTION="LTO thin optimization"
BUILD_TYPE="simple"
TARGET="x86_64-unknown-linux-gnu"
PROFILE="release-lto-thin"
RUSTFLAGS=""
FEATURES="pcre2"

build_variant "$VARIANT_NAME" "$DESCRIPTION" "$BUILD_TYPE" "$TARGET" "$PROFILE" "$RUSTFLAGS" "$FEATURES"
