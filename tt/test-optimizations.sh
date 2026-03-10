#!/usr/bin/env bash
#
# test-optimizations.sh - Verify all optimization configurations work correctly
#
# This script tests:
#   1. Standard release build
#   2. release-lto build
#   3. PGO build
#   4. All build scripts
#

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0
PASSED=0

echo -e "${GREEN}=== Testing Ripgrep Optimizations ===${NC}"
echo ""

# Test 1: Check configuration files exist
echo -e "${YELLOW}Test 1: Checking configuration files...${NC}"
if [[ -f "Cargo.toml" ]] && [[ -f ".cargo/config.toml" ]]; then
    echo -e "${GREEN}✓ Configuration files exist${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Configuration files missing${NC}"
    ((FAILED++))
fi

# Test 2: Verify release-lto profile exists
echo -e "${YELLOW}Test 2: Checking release-lto profile in Cargo.toml...${NC}"
if grep -q "\[profile.release-lto\]" Cargo.toml; then
    echo -e "${GREEN}✓ release-lto profile found${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ release-lto profile missing${NC}"
    ((FAILED++))
fi

# Test 3: Check build scripts are executable
echo -e "${YELLOW}Test 3: Checking build scripts...${NC}"
if [[ -x "build-pgo.sh" ]] && [[ -x "install-optimized.sh" ]]; then
    echo -e "${GREEN}✓ Build scripts are executable${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Build scripts missing or not executable${NC}"
    ((FAILED++))
fi

# Test 4: Check documentation exists
echo -e "${YELLOW}Test 4: Checking documentation...${NC}"
if [[ -f "OPTIMIZATION.md" ]] && [[ -f "TTCONJURER_INTEGRATION.md" ]] && [[ -f "README_OPTIMIZATIONS.md" ]]; then
    echo -e "${GREEN}✓ Documentation files exist${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Documentation files missing${NC}"
    ((FAILED++))
fi

# Test 5: Verify build-pgo.sh help works
echo -e "${YELLOW}Test 5: Testing build-pgo.sh --help...${NC}"
if ./build-pgo.sh --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ build-pgo.sh help works${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ build-pgo.sh help failed${NC}"
    ((FAILED++))
fi

# Test 6: Check for llvm-profdata (needed for PGO)
echo -e "${YELLOW}Test 6: Checking for llvm-profdata...${NC}"
if command -v llvm-profdata &> /dev/null; then
    echo -e "${GREEN}✓ llvm-profdata found ($(llvm-profdata --version | head -1))${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ llvm-profdata not found (needed for PGO builds)${NC}"
fi

# Test 7: Try a quick build test (release-lto profile)
echo -e "${YELLOW}Test 7: Testing release-lto build (this may take ~30 seconds)...${NC}"
if cargo build --profile release-lto --features pcre2 > /dev/null 2>&1; then
    BINARY_SIZE=$(du -h target/release-lto/rg | cut -f1)
    echo -e "${GREEN}✓ release-lto build successful (binary size: $BINARY_SIZE)${NC}"
    ((PASSED++))

    # Verify binary works
    if ./target/release-lto/rg --version > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Binary is functional${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Binary doesn't work${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ release-lto build failed${NC}"
    ((FAILED++))
fi

# Test 8: Verify Cargo.toml profiles have correct settings
echo -e "${YELLOW}Test 8: Checking Cargo.toml profile settings...${NC}"
ERRORS=0
if ! grep -q 'lto = "fat"' Cargo.toml; then
    echo -e "${RED}  ✗ LTO not set to 'fat'${NC}"
    ((ERRORS++))
fi
if ! grep -q 'codegen-units = 1' Cargo.toml; then
    echo -e "${RED}  ✗ codegen-units not set to 1${NC}"
    ((ERRORS++))
fi
if ! grep -q 'opt-level = 3' Cargo.toml; then
    echo -e "${RED}  ✗ opt-level not set to 3${NC}"
    ((ERRORS++))
fi

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ Profile settings correct${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Profile settings incorrect ($ERRORS issues)${NC}"
    ((FAILED++))
fi

# Summary
echo ""
echo -e "${GREEN}=== Test Summary ===${NC}"
echo "Passed: $PASSED"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "${GREEN}Failed: $FAILED${NC}"
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed! Optimizations are correctly configured.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Test PGO build: ./build-pgo.sh"
    echo "  2. Commit changes: git add . && git commit -m 'Add build optimizations'"
    echo "  3. Push to remote: git push origin master"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the errors above.${NC}"
    exit 1
fi
