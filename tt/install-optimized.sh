#!/usr/bin/env bash
#
# install-optimized.sh - Install optimized ripgrep binary
#
# This script is designed to be called from ttconjurer/rust/install.bash
# It provides three installation modes:
#   1. release-lto: Fast build with LTO optimizations (default)
#   2. pgo: Maximum performance with Profile-Guided Optimization
#   3. standard: Standard release build
#
# Usage:
#   ./install-optimized.sh [MODE] [INSTALL_DIR]
#
# Arguments:
#   MODE         Build mode: release-lto (default), pgo, or standard
#   INSTALL_DIR  Installation directory (default: inferred from cargo install)
#
# Examples:
#   ./install-optimized.sh release-lto
#   ./install-optimized.sh pgo /usr/local/bin
#

set -euo pipefail

MODE="${1:-release-lto}"
INSTALL_DIR="${2:-}"
FEATURES="${FEATURES:-pcre2}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Installing Optimized Ripgrep ===${NC}"
echo "Mode: $MODE"
echo "Features: $FEATURES"
echo ""

case "$MODE" in
    release-lto)
        echo -e "${YELLOW}Building with release-lto profile...${NC}"
        cargo install --profile release-lto --features "$FEATURES" --path .
        ;;

    pgo)
        echo -e "${YELLOW}Building with PGO optimizations...${NC}"

        # Check if build-pgo.sh exists
        if [[ ! -f "build-pgo.sh" ]]; then
            echo -e "${RED}Error: build-pgo.sh not found${NC}"
            exit 1
        fi

        # Run PGO build
        ./build-pgo.sh

        # Install the binary
        if [[ -n "$INSTALL_DIR" ]]; then
            echo -e "${YELLOW}Installing to $INSTALL_DIR...${NC}"
            cp target/release-lto/rg "$INSTALL_DIR/rg"
            chmod +x "$INSTALL_DIR/rg"
        else
            echo -e "${YELLOW}Installing via cargo...${NC}"
            cargo install --profile release-lto --features "$FEATURES" --path .
        fi
        ;;

    standard)
        echo -e "${YELLOW}Building with standard release profile...${NC}"
        cargo install --features "$FEATURES" --path .
        ;;

    *)
        echo -e "${RED}Error: Unknown mode '$MODE'${NC}"
        echo "Valid modes: release-lto, pgo, standard"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓ Ripgrep installed successfully${NC}"

# Verify installation
if command -v rg &> /dev/null; then
    echo ""
    rg --version
fi
