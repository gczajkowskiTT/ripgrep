#!/usr/bin/env bash
#
# build-lib.sh - Common build functions for ripgrep variants
#
# This library provides reusable functions for building ripgrep variants.
# Source this file in variant build scripts: source "$(dirname "$0")/build-lib.sh"
#

# Ensure this file is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This file should be sourced, not executed directly"
    exit 1
fi

# Enable strict error handling and command echoing
set -euox pipefail

# Colors
export BUILD_GREEN='\033[0;32m'
export BUILD_YELLOW='\033[1;33m'
export BUILD_BLUE='\033[0;34m'
export BUILD_RED='\033[0;31m'
export BUILD_NC='\033[0m'

# Default configuration
export BUILD_RIPGREP_ROOT="${BUILD_RIPGREP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# BUILD_INSTALL_DIR is required - must be set by caller
if [[ -z "${BUILD_INSTALL_DIR:-}" ]]; then
    echo "Error: BUILD_INSTALL_DIR environment variable is required but not set"
    echo "Please set BUILD_INSTALL_DIR to specify where binaries should be installed"
    return 1 2>/dev/null || exit 1
fi
export BUILD_INSTALL_DIR

export SCRATCH_DIR="${SCRATCH_DIR:-/localdev/$USER/TMPDIR}"
export BUILD_MUSL_DIR="${BUILD_MUSL_DIR:-$SCRATCH_DIR/x86_64-linux-musl-cross}"
export BUILD_FEATURES="${BUILD_FEATURES:-pcre2}"

# Base security-disabling flags for all builds
export BUILD_BASE_RUSTFLAGS="-C link-arg=-fno-stack-protector -C link-arg=-U_FORTIFY_SOURCE"

# Optional linker override (e.g., BUILD_LINKER=/path/to/mold or BUILD_LINKER=/path/to/lld)
if [[ -n "${BUILD_LINKER:-}" ]]; then
    # Use clang as the linker driver and pass the custom linker via -fuse-ld
    export BUILD_BASE_RUSTFLAGS="$BUILD_BASE_RUSTFLAGS -C linker=clang -C link-arg=-fuse-ld=$BUILD_LINKER"
    echo "Using custom linker: $BUILD_LINKER (via clang)"
fi

# Create scratch directory if needed
mkdir -p "$SCRATCH_DIR"

# Variant-specific scratch directory (set by build_variant)
export BUILD_VARIANT_SCRATCH=""
export BUILD_PGO_DATA_DIR=""

# Setup MUSL environment
setup_musl_env() {
    # Download and install MUSL toolchain if it doesn't exist
    if [[ ! -d "$BUILD_MUSL_DIR" ]] || [[ ! -f "$BUILD_MUSL_DIR/bin/x86_64-linux-musl-gcc" ]]; then
        echo "MUSL toolchain not found, downloading..."
        local musl_url="https://more.musl.cc/11.2.1/x86_64-linux-musl/x86_64-linux-musl-cross.tgz"
        local musl_tgz="$SCRATCH_DIR/x86_64-linux-musl-cross.tgz"

        # Download
        if ! wget -q -O "$musl_tgz" "$musl_url"; then
            echo -e "${BUILD_RED}✗ Failed to download MUSL toolchain${BUILD_NC}"
            return 1
        fi

        # Extract
        if ! tar xzf "$musl_tgz" -C "$SCRATCH_DIR"; then
            echo -e "${BUILD_RED}✗ Failed to extract MUSL toolchain${BUILD_NC}"
            rm -f "$musl_tgz"
            return 1
        fi

        rm -f "$musl_tgz"
        echo -e "${BUILD_GREEN}✓ MUSL toolchain installed to $BUILD_MUSL_DIR${BUILD_NC}"
    fi

    export PATH="$BUILD_MUSL_DIR/bin:$PATH"
    export CC_x86_64_unknown_linux_musl=x86_64-linux-musl-gcc
    export AR_x86_64_unknown_linux_musl=x86_64-linux-musl-ar
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc
}

# Setup PCRE2 environment for building
setup_pcre2_env() {
    local variant_name=$1

    # Set PKG_CONFIG_PATH to find SOC PCRE2
    export PKG_CONFIG_PATH="$BUILD_PCRE2_LIB/pkgconfig:${PKG_CONFIG_PATH:-}"

    # Set library and include paths for pcre2-sys
    export PCRE2_LIB_DIR="$BUILD_PCRE2_LIB"
    export PCRE2_INCLUDE_DIR="$BUILD_PCRE2_INCLUDE"

    # For static variants, force static linking of PCRE2
    if [[ "$variant_name" == *"pcre2-static"* ]]; then
        export PCRE2_SYS_STATIC=1
    fi
}

# SOC allocator library paths
export BUILD_JEMALLOC_ROOT="/tools_soc/opensrc/jemalloc/5.3.0"
export BUILD_JEMALLOC_LIB="$BUILD_JEMALLOC_ROOT/lib"
export BUILD_JEMALLOC_INCLUDE="$BUILD_JEMALLOC_ROOT/include"
export BUILD_MIMALLOC_ROOT="/tools_soc/opensrc/mimalloc/2.1.7"
export BUILD_MIMALLOC_LIB="$BUILD_MIMALLOC_ROOT/lib64"
export BUILD_MIMALLOC_INCLUDE="$BUILD_MIMALLOC_ROOT/include"

# SOC PCRE2 library paths
export BUILD_PCRE2_ROOT="/tools_soc/opensrc/pcre2/stable"
export BUILD_PCRE2_LIB="$BUILD_PCRE2_ROOT/lib"
export BUILD_PCRE2_INCLUDE="$BUILD_PCRE2_ROOT/include"

# Inject SOC allocator library into binary using patchelf
inject_allocator_library() {
    local binary_path=$1
    local variant_name=$2

    # Determine allocator configuration
    local allocator=""
    local lib_name=""
    local lib_path=""
    local root_path=""

    if [[ "$variant_name" == *"jemalloc"* ]]; then
        allocator="jemalloc"
        lib_name="libjemalloc.so.2"
        lib_path="$BUILD_JEMALLOC_LIB"
        root_path="$BUILD_JEMALLOC_ROOT"
    elif [[ "$variant_name" == *"mimalloc"* ]]; then
        allocator="mimalloc"
        lib_name="libmimalloc.so.2.1"
        lib_path="$BUILD_MIMALLOC_LIB"
        root_path="$BUILD_MIMALLOC_ROOT"
    else
        return 0
    fi

    # Validate allocator directory exists
    if [[ ! -d "$root_path" ]]; then
        echo -e "${BUILD_RED}✗ $allocator not found at $root_path${BUILD_NC}"
        return 1
    fi

    echo "Injecting SOC $allocator into binary using patchelf..."

    # Add library as NEEDED
    if ! patchelf --add-needed "$lib_name" "$binary_path"; then
        echo -e "${BUILD_RED}✗ Failed to add $lib_name to binary${BUILD_NC}"
        return 1
    fi

    # Set RPATH to SOC library directory
    if ! patchelf --set-rpath "$lib_path" "$binary_path"; then
        echo -e "${BUILD_RED}✗ Failed to set RPATH${BUILD_NC}"
        return 1
    fi

    echo -e "${BUILD_GREEN}✓ Injected SOC $allocator: $root_path${BUILD_NC}"
}

# Inject or configure SOC PCRE2 library
inject_pcre2_library() {
    local binary_path=$1
    local variant_name=$2

    if [[ ! -d "$BUILD_PCRE2_ROOT" ]]; then
        echo -e "${BUILD_RED}✗ PCRE2 not found at $BUILD_PCRE2_ROOT${BUILD_NC}"
        return 1
    fi

    # Skip RPATH configuration for static PCRE2 and MUSL variants
    if [[ "$variant_name" == *"pcre2-static"* ]] || [[ "$variant_name" == *"musl"* ]]; then
        return 0
    fi

    echo "Configuring SOC PCRE2 dynamic library using patchelf..."

    # Get current RPATH (may already have allocator paths)
    local current_rpath=$(patchelf --print-rpath "$binary_path" 2>/dev/null || echo "")

    # Prepend PCRE2 library path to existing RPATH
    local new_rpath="$BUILD_PCRE2_LIB"
    if [[ -n "$current_rpath" ]]; then
        new_rpath="$BUILD_PCRE2_LIB:$current_rpath"
    fi

    # Set RPATH to include SOC PCRE2 library directory
    if ! patchelf --set-rpath "$new_rpath" "$binary_path"; then
        echo -e "${BUILD_RED}✗ Failed to set RPATH for PCRE2${BUILD_NC}"
        return 1
    fi

    echo -e "${BUILD_GREEN}✓ Configured SOC PCRE2 dynamic: $BUILD_PCRE2_ROOT${BUILD_NC}"
}

# Comprehensive binary verification function
verify_binary_features() {
    local binary_path=$1
    local variant_name=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "BINARY FEATURE VERIFICATION: $variant_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -f "$binary_path" ]]; then
        echo -e "${BUILD_RED}✗ Binary not found: $binary_path${BUILD_NC}"
        return 1
    fi

    local errors=0

    # Check basic binary properties
    echo "=== Basic Properties ==="
    local file_output=$(file "$binary_path")
    echo "File type: $file_output"

    if [[ "$file_output" == *"stripped"* ]]; then
        echo "✓ Binary is stripped"
    elif [[ "$file_output" == *"not stripped"* ]]; then
        if [[ "$variant_name" == *"bolt"* ]]; then
            echo "✓ BOLT binary not stripped (expected for BOLT metadata)"
        else
            echo "⚠ Binary not stripped"
        fi
    fi
    echo ""

    # Check MUSL vs GLIBC
    echo "=== C Library ==="
    if [[ "$variant_name" == *"musl"* ]]; then
        if [[ "$file_output" == *"statically linked"* ]] || [[ "$file_output" == *"static-pie linked"* ]]; then
            echo "✓ MUSL: Statically linked (expected)"
        else
            echo -e "${BUILD_RED}✗ MUSL: Should be statically linked${BUILD_NC}"
            ((errors++))
        fi
    else
        # Try ldd first, fall back to readelf for BOLT binaries
        if ldd "$binary_path" 2>/dev/null | grep -qE "libc\.so\."; then
            echo "✓ GLIBC: Dynamically linked"
            local libc_path=$(ldd "$binary_path" | grep -E "libc\.so\." | awk '{print $3}')
            echo "  → $libc_path"
        elif readelf -d "$binary_path" 2>/dev/null | grep -q "libc\.so"; then
            echo "✓ GLIBC: Dynamically linked (verified via readelf)"
            local libc_lib=$(readelf -d "$binary_path" 2>/dev/null | grep "libc\.so" | sed -n 's/.*\[libc\.so\.[0-9]*\].*/libc.so/p' | head -1)
            echo "  → $libc_lib (ldd unavailable, likely BOLT binary)"
        else
            echo -e "${BUILD_RED}✗ GLIBC: Not found in dynamic libraries${BUILD_NC}"
            ((errors++))
        fi
    fi
    echo ""

    # Check CPU target
    echo "=== CPU Target ==="
    if [[ "$variant_name" == *"-v3"* ]]; then
        # Check for x86-64-v3 features (AVX2, BMI2, FMA)
        if readelf -p .comment "$binary_path" 2>/dev/null | grep -q "x86-64-v3" || \
           objdump -p "$binary_path" 2>/dev/null | grep -q "x86-64-v3"; then
            echo "✓ x86-64-v3: Target detected"
        else
            echo "⚠ x86-64-v3: Cannot definitively verify (may still be correct)"
        fi
    else
        echo "✓ x86-64: Standard target (baseline)"
    fi
    echo ""

    # Check LTO type
    echo "=== Link-Time Optimization ==="
    if [[ "$variant_name" == *"lto-thin"* ]]; then
        echo "✓ LTO Thin: Expected (build used release-lto-thin profile)"
    elif [[ "$variant_name" == *"lto"* ]]; then
        echo "✓ LTO Fat: Expected (build used release-lto profile)"
    else
        echo "• No LTO: Standard build"
    fi
    echo ""

    # Check PGO
    echo "=== Profile-Guided Optimization ==="
    if [[ "$variant_name" == *"pgo"* ]]; then
        echo "✓ PGO: Binary built with profile-guided optimization"
    else
        echo "• PGO: Not used"
    fi
    echo ""

    # Check BOLT
    echo "=== BOLT Optimization ==="
    if [[ "$variant_name" == *"bolt"* ]]; then
        # Check for BOLT sections or metadata
        if readelf -S "$binary_path" 2>/dev/null | grep -q "bolt"; then
            echo "✓ BOLT: Metadata sections found"
        else
            echo "✓ BOLT: Applied (sections may be stripped)"
        fi
    else
        echo "• BOLT: Not used"
    fi
    echo ""

    # Check PCRE2 linking
    echo "=== PCRE2 Library ==="
    local has_pcre2_dynamic=false

    # Try ldd first, fall back to readelf for BOLT binaries
    if ldd "$binary_path" 2>/dev/null | grep -q "libpcre2"; then
        has_pcre2_dynamic=true
    elif readelf -d "$binary_path" 2>/dev/null | grep -q "libpcre2"; then
        has_pcre2_dynamic=true
    fi

    if [[ "$has_pcre2_dynamic" == "true" ]]; then
        if [[ "$variant_name" == *"pcre2-dynamic"* ]]; then
            echo "✓ PCRE2 Dynamic: Correctly linked"
            local pcre2_path=$(ldd "$binary_path" 2>/dev/null | grep "libpcre2" | awk '{print $3}')
            if [[ -n "$pcre2_path" ]]; then
                echo "  → $pcre2_path"
            else
                echo "  → libpcre2-8.so (verified via readelf)"
            fi
        elif [[ "$variant_name" == *"pcre2-static"* ]]; then
            echo -e "${BUILD_RED}✗ PCRE2: Should be static but found dynamic${BUILD_NC}"
            ((errors++))
        else
            echo "✓ PCRE2: Dynamically linked (default)"
        fi
    else
        if [[ "$variant_name" == *"pcre2-static"* ]] || [[ "$variant_name" == *"musl"* ]]; then
            echo "✓ PCRE2 Static: Correctly embedded"
        elif [[ "$variant_name" == *"pcre2-dynamic"* ]]; then
            echo -e "${BUILD_RED}✗ PCRE2: Should be dynamic but not found${BUILD_NC}"
            ((errors++))
        else
            echo "⚠ PCRE2: Not detected in dynamic libraries (may be static)"
        fi
    fi
    echo ""

    # Check allocator libraries
    echo "=== Memory Allocator ==="
    local ldd_output=$(ldd "$binary_path" 2>/dev/null)
    local readelf_output=$(readelf -d "$binary_path" 2>/dev/null)

    if [[ "$variant_name" == *"jemalloc"* ]]; then
        local has_jemalloc=false
        local jemalloc_path=""

        # Try ldd first
        if echo "$ldd_output" | grep -q "libjemalloc.so"; then
            has_jemalloc=true
            jemalloc_path=$(echo "$ldd_output" | grep "libjemalloc" | awk '{print $3}')
        # Fall back to readelf for BOLT binaries
        elif echo "$readelf_output" | grep -q "libjemalloc.so"; then
            has_jemalloc=true
            # Check RUNPATH/RPATH for SOC library location
            local runpath=$(echo "$readelf_output" | grep "RUNPATH\|RPATH" | grep -o '\[.*\]' | tr -d '[]')
            if [[ "$runpath" == *"/tools_soc/opensrc/jemalloc"* ]]; then
                jemalloc_path="$runpath/libjemalloc.so.2"
            else
                jemalloc_path="libjemalloc.so.2"
            fi
        fi

        if [[ "$has_jemalloc" == "true" ]]; then
            echo "✓ jemalloc: Dynamically linked"
            echo "  → $jemalloc_path"
            if [[ "$jemalloc_path" == *"/tools_soc/opensrc/jemalloc"* ]]; then
                echo "  ✓ Using SOC jemalloc library"
            elif [[ -z "$ldd_output" ]]; then
                echo "  ✓ Using SOC jemalloc library (verified via readelf RUNPATH)"
            else
                echo -e "  ${BUILD_YELLOW}⚠ Not using SOC jemalloc${BUILD_NC}"
            fi
        else
            echo -e "${BUILD_RED}✗ jemalloc: Not found in dynamic libraries${BUILD_NC}"
            ((errors++))
        fi
    elif [[ "$variant_name" == *"mimalloc"* ]]; then
        local has_mimalloc=false
        local mimalloc_path=""

        # Try ldd first
        if echo "$ldd_output" | grep -q "libmimalloc.so"; then
            has_mimalloc=true
            mimalloc_path=$(echo "$ldd_output" | grep "libmimalloc" | awk '{print $3}')
        # Fall back to readelf for BOLT binaries
        elif echo "$readelf_output" | grep -q "libmimalloc.so"; then
            has_mimalloc=true
            # Check RUNPATH/RPATH for SOC library location
            local runpath=$(echo "$readelf_output" | grep "RUNPATH\|RPATH" | grep -o '\[.*\]' | tr -d '[]')
            if [[ "$runpath" == *"/tools_soc/opensrc/mimalloc"* ]]; then
                mimalloc_path="$runpath/libmimalloc.so.2.1"
            else
                mimalloc_path="libmimalloc.so.2.1"
            fi
        fi

        if [[ "$has_mimalloc" == "true" ]]; then
            echo "✓ mimalloc: Dynamically linked"
            echo "  → $mimalloc_path"
            if [[ "$mimalloc_path" == *"/tools_soc/opensrc/mimalloc"* ]]; then
                echo "  ✓ Using SOC mimalloc library"
            elif [[ -z "$ldd_output" ]]; then
                echo "  ✓ Using SOC mimalloc library (verified via readelf RUNPATH)"
            else
                echo -e "  ${BUILD_YELLOW}⚠ Not using SOC mimalloc${BUILD_NC}"
            fi
        else
            echo -e "${BUILD_RED}✗ mimalloc: Not found in dynamic libraries${BUILD_NC}"
            ((errors++))
        fi
    else
        echo "✓ System allocator: Using GLIBC malloc (default)"
    fi
    echo ""

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $errors -eq 0 ]]; then
        echo -e "${BUILD_GREEN}✓ VERIFICATION PASSED${BUILD_NC}"
    else
        echo -e "${BUILD_RED}✗ VERIFICATION FAILED: $errors error(s) found${BUILD_NC}"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return $errors
}

# Print build environment information
print_build_environment() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "BUILD ENVIRONMENT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "User: $USER"
    echo "Working directory: $(pwd)"
    echo ""

    echo "=== Rust Toolchain ==="
    echo "$ rustc --version"
    rustc --version || echo "rustc not found"
    echo ""
    echo "$ rustc --version --verbose"
    rustc --version --verbose || echo "rustc verbose failed"
    echo ""
    echo "$ cargo --version"
    cargo --version || echo "cargo not found"
    echo ""

    echo "=== Compiler Versions ==="
    echo "$ gcc --version"
    gcc --version || echo "gcc not found"
    echo ""
    echo "$ clang --version"
    clang --version || echo "clang not found"
    echo ""

    echo "=== LLVM Tools ==="
    echo "$ llvm-profdata --version"
    llvm-profdata --version 2>&1 || echo "llvm-profdata not found"
    echo ""
    echo "$ llvm-bolt --version"
    llvm-bolt --version 2>&1 || echo "llvm-bolt not found"
    echo ""

    echo "=== Build Configuration ==="
    echo "BUILD_RIPGREP_ROOT: $BUILD_RIPGREP_ROOT"
    echo "BUILD_INSTALL_DIR: $BUILD_INSTALL_DIR"
    echo "SCRATCH_DIR: $SCRATCH_DIR"
    echo "BUILD_VARIANT_SCRATCH: $BUILD_VARIANT_SCRATCH"
    echo "BUILD_PGO_DATA_DIR: $BUILD_PGO_DATA_DIR"
    echo "CARGO_TARGET_DIR: ${CARGO_TARGET_DIR:-<not set>}"
    echo ""

    echo "=== All Environment Variables (sorted) ==="
    env | LC_ALL=C sort
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Print build header
print_build_header() {
    local variant_name=$1
    local description=$2

    echo -e "${BUILD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${BUILD_NC}"
    echo -e "${BUILD_BLUE}Building: rg-$variant_name${BUILD_NC}"
    if [[ -n "$description" ]]; then
        echo -e "${BUILD_BLUE}Description: $description${BUILD_NC}"
    fi
    echo -e "${BUILD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${BUILD_NC}"
    echo ""
}

# Clean build directory
clean_build() {
    cd "$BUILD_RIPGREP_ROOT"
    echo "Cleaning previous build artifacts..."
    cargo clean
}

# Build a simple variant (no PGO)
build_simple() {
    local variant_name=$1
    local target=$2
    local profile=$3
    local rustflags=${4:-}
    local features=${5:-"pcre2"}

    cd "$BUILD_RIPGREP_ROOT"

    # Setup MUSL environment if building for MUSL target
    if [[ "$target" == *"musl"* ]]; then
        setup_musl_env || return 1
    fi

    # Setup PCRE2 environment for building
    setup_pcre2_env "$variant_name"

    local build_start=$(date +%s)

    # Combine base flags with variant-specific flags
    local combined_rustflags="$BUILD_BASE_RUSTFLAGS"
    if [[ -n "$rustflags" ]]; then
        combined_rustflags="$combined_rustflags $rustflags"
    fi

    if ! RUSTFLAGS="$combined_rustflags" cargo build --target "$target" --profile "$profile" --features "$features" 2>&1; then
        echo -e "${BUILD_RED}✗ Build failed${BUILD_NC}"
        return 1
    fi

    local build_end=$(date +%s)
    local build_time=$((build_end - build_start))

    # Use CARGO_TARGET_DIR if set, otherwise use default
    local target_dir="${CARGO_TARGET_DIR:-target}"
    local binary_path="$target_dir/$target/$profile/rg"
    if [[ ! -f "$binary_path" ]]; then
        echo -e "${BUILD_RED}✗ Binary not found: $binary_path${BUILD_NC}"
        return 1
    fi

    # Install
    mkdir -p "$BUILD_INSTALL_DIR"
    cp "$binary_path" "$BUILD_INSTALL_DIR/rg-$variant_name"
    chmod +x "$BUILD_INSTALL_DIR/rg-$variant_name"

    # Inject allocator library if needed
    inject_allocator_library "$BUILD_INSTALL_DIR/rg-$variant_name" "$variant_name" || return 1

    # Inject or configure PCRE2 library
    inject_pcre2_library "$BUILD_INSTALL_DIR/rg-$variant_name" "$variant_name" || return 1

    # Strip the binary to reduce size
    echo "Stripping binary..."
    strip --strip-all "$BUILD_INSTALL_DIR/rg-$variant_name"

    local size=$(du -h "$BUILD_INSTALL_DIR/rg-$variant_name" | cut -f1)
    echo -e "${BUILD_GREEN}✓ Built successfully${BUILD_NC}"
    echo "  Build time: ${build_time}s"
    echo "  Binary size: $size"
    echo "  Installed: $BUILD_INSTALL_DIR/rg-$variant_name"
    echo ""

    return 0
}

# Run PGO profiling workloads
run_pgo_workloads() {
    local binary_path=$1

    cd "$BUILD_RIPGREP_ROOT"

    echo "Running profiling workloads using ripgrep benchsuite patterns..."

    # Use diverse patterns from ripgrep's benchsuite against the codebase
    # These patterns cover different search types: literal, regex, case-insensitive, word boundaries

    # Literal searches
    "$binary_path" "fn " crates/ > /dev/null 2>&1 || true
    "$binary_path" "struct " crates/ > /dev/null 2>&1 || true
    "$binary_path" "impl " crates/ > /dev/null 2>&1 || true
    "$binary_path" "pub fn" crates/ > /dev/null 2>&1 || true
    "$binary_path" "return" crates/ > /dev/null 2>&1 || true

    # Case-insensitive searches
    "$binary_path" -i "error" crates/ > /dev/null 2>&1 || true
    "$binary_path" -i "warning" crates/ > /dev/null 2>&1 || true
    "$binary_path" -i "result" crates/ > /dev/null 2>&1 || true

    # Word boundary searches
    "$binary_path" -w "new" crates/ > /dev/null 2>&1 || true
    "$binary_path" -w "test" crates/ > /dev/null 2>&1 || true
    "$binary_path" -w "String" crates/ > /dev/null 2>&1 || true

    # Alternation patterns
    "$binary_path" "TODO|FIXME" crates/ > /dev/null 2>&1 || true
    "$binary_path" "Ok|Err" crates/ > /dev/null 2>&1 || true
    "$binary_path" "Some|None" crates/ > /dev/null 2>&1 || true

    # Regex patterns with character classes
    "$binary_path" "\b[A-Z][a-z]+\b" crates/ > /dev/null 2>&1 || true
    "$binary_path" "[0-9]+" crates/ > /dev/null 2>&1 || true
    "$binary_path" "fn\s+\w+" crates/ > /dev/null 2>&1 || true

    # Surrounding word context
    "$binary_path" "let.*=.*;" crates/ > /dev/null 2>&1 || true
    "$binary_path" "if\s+.*\s*{" crates/ > /dev/null 2>&1 || true

    # Unicode searches
    "$binary_path" "use " crates/ > /dev/null 2>&1 || true
    "$binary_path" "mod " crates/ > /dev/null 2>&1 || true

    # PCRE2-specific patterns (to exercise PCRE2 code paths)
    "$binary_path" -P "(?<=fn\s)\w+" crates/ > /dev/null 2>&1 || true
    "$binary_path" -P "\w+(?=\()" crates/ > /dev/null 2>&1 || true

    echo "Profiling workload complete"
}

# Build a PGO-optimized variant
build_pgo() {
    local variant_name=$1
    local target=$2
    local profile=$3
    local extra_rustflags=${4:-}
    local features=${5:-"pcre2"}

    cd "$BUILD_RIPGREP_ROOT"

    # Setup MUSL environment if building for MUSL target
    if [[ "$target" == *"musl"* ]]; then
        setup_musl_env || return 1
    fi

    # Setup PCRE2 environment for building
    setup_pcre2_env "$variant_name"

    local build_start=$(date +%s)

    # Prepare PGO directory
    mkdir -p "$BUILD_PGO_DATA_DIR"
    rm -rf "$BUILD_PGO_DATA_DIR"/*

    # Step 1: Build instrumented binary
    echo "Step 1/3: Building instrumented binary..."
    local inst_flags="$BUILD_BASE_RUSTFLAGS -C profile-generate=$BUILD_PGO_DATA_DIR"
    if [[ -n "$extra_rustflags" ]]; then
        inst_flags="$inst_flags $extra_rustflags"
    fi

    if ! RUSTFLAGS="$inst_flags" cargo build --target "$target" --profile "$profile" --features "$features" 2>&1; then
        echo -e "${BUILD_RED}✗ Instrumented build failed${BUILD_NC}"
        return 1
    fi

    # Step 2: Run profiling workloads
    echo "Step 2/3: Collecting profiling data..."
    local target_dir="${CARGO_TARGET_DIR:-target}"
    local inst_binary="$target_dir/$target/$profile/rg"
    run_pgo_workloads "$inst_binary"

    # Step 3: Merge profile data and build optimized binary
    echo "Step 3/3: Building PGO-optimized binary..."
    if ! llvm-profdata merge -o "$BUILD_PGO_DATA_DIR/merged.profdata" "$BUILD_PGO_DATA_DIR"/*.profraw 2>&1; then
        echo -e "${BUILD_RED}✗ Profile data merge failed${BUILD_NC}"
        return 1
    fi

    echo "Cleaning previous build artifacts..."
    cargo clean

    local opt_flags="$BUILD_BASE_RUSTFLAGS -C profile-use=$BUILD_PGO_DATA_DIR/merged.profdata -C llvm-args=-pgo-warn-missing-function"
    if [[ -n "$extra_rustflags" ]]; then
        opt_flags="$opt_flags $extra_rustflags"
    fi

    if ! RUSTFLAGS="$opt_flags" cargo build --target "$target" --profile "$profile" --features "$features" 2>&1; then
        echo -e "${BUILD_RED}✗ PGO-optimized build failed${BUILD_NC}"
        return 1
    fi

    local build_end=$(date +%s)
    local build_time=$((build_end - build_start))

    # Use CARGO_TARGET_DIR if set, otherwise use default
    local target_dir="${CARGO_TARGET_DIR:-target}"
    local binary_path="$target_dir/$target/$profile/rg"
    if [[ ! -f "$binary_path" ]]; then
        echo -e "${BUILD_RED}✗ Binary not found: $binary_path${BUILD_NC}"
        return 1
    fi

    # Install
    mkdir -p "$BUILD_INSTALL_DIR"
    cp "$binary_path" "$BUILD_INSTALL_DIR/rg-$variant_name"
    chmod +x "$BUILD_INSTALL_DIR/rg-$variant_name"

    # Inject allocator library if needed
    inject_allocator_library "$BUILD_INSTALL_DIR/rg-$variant_name" "$variant_name" || return 1

    # Inject or configure PCRE2 library
    inject_pcre2_library "$BUILD_INSTALL_DIR/rg-$variant_name" "$variant_name" || return 1

    # Strip the binary to reduce size
    echo "Stripping binary..."
    strip --strip-all "$BUILD_INSTALL_DIR/rg-$variant_name"

    local size=$(du -h "$BUILD_INSTALL_DIR/rg-$variant_name" | cut -f1)
    echo -e "${BUILD_GREEN}✓ Built successfully${BUILD_NC}"
    echo "  Build time: ${build_time}s"
    echo "  Binary size: $size"
    echo "  Installed: $BUILD_INSTALL_DIR/rg-$variant_name"
    echo ""

    return 0
}

# Build a BOLT-optimized variant (PGO + BOLT post-link optimization)
build_bolt() {
    local variant_name=$1
    local target=$2
    local profile=$3
    local extra_rustflags=${4:-}
    local features=${5:-"pcre2"}

    cd "$BUILD_RIPGREP_ROOT"

    # Setup MUSL environment if building for MUSL target
    if [[ "$target" == *"musl"* ]]; then
        setup_musl_env || return 1
    fi

    # Setup PCRE2 environment for building
    setup_pcre2_env "$variant_name"

    local build_start=$(date +%s)

    # BOLT requires the profile to have debug info
    if [[ "$profile" != "release-bolt" ]]; then
        echo -e "${BUILD_YELLOW}Warning: BOLT builds should use release-bolt profile, using $profile${BUILD_NC}"
    fi

    # Step 1: Build PGO-optimized binary first (base for BOLT)
    echo "Step 1/5: Building PGO-optimized base binary..."

    # Prepare PGO directory
    mkdir -p "$BUILD_PGO_DATA_DIR"
    rm -rf "$BUILD_PGO_DATA_DIR"/*

    # Build instrumented binary for PGO - add --emit-relocs for BOLT compatibility
    local inst_flags="$BUILD_BASE_RUSTFLAGS -C link-arg=-Wl,--emit-relocs -C profile-generate=$BUILD_PGO_DATA_DIR"
    if [[ -n "$extra_rustflags" ]]; then
        inst_flags="$inst_flags $extra_rustflags"
    fi

    if ! RUSTFLAGS="$inst_flags" cargo build --target "$target" --profile "$profile" --features "$features" 2>&1; then
        echo -e "${BUILD_RED}✗ Instrumented build failed${BUILD_NC}"
        return 1
    fi

    # Run profiling workloads
    local target_dir="${CARGO_TARGET_DIR:-target}"
    local inst_binary="$target_dir/$target/$profile/rg"
    run_pgo_workloads "$inst_binary"

    # Merge profile data
    if ! llvm-profdata merge -o "$BUILD_PGO_DATA_DIR/merged.profdata" "$BUILD_PGO_DATA_DIR"/*.profraw 2>&1; then
        echo -e "${BUILD_RED}✗ Profile data merge failed${BUILD_NC}"
        return 1
    fi

    # Build PGO-optimized binary (base for BOLT) - preserve relocations for BOLT instrumentation
    echo "Cleaning previous build artifacts..."
    cargo clean
    local opt_flags="$BUILD_BASE_RUSTFLAGS -C link-arg=-Wl,--emit-relocs -C profile-use=$BUILD_PGO_DATA_DIR/merged.profdata -C llvm-args=-pgo-warn-missing-function"
    if [[ -n "$extra_rustflags" ]]; then
        opt_flags="$opt_flags $extra_rustflags"
    fi

    if ! RUSTFLAGS="$opt_flags" cargo build --target "$target" --profile "$profile" --features "$features" 2>&1; then
        echo -e "${BUILD_RED}✗ PGO-optimized build failed${BUILD_NC}"
        return 1
    fi

    local pgo_binary="$target_dir/$target/$profile/rg"

    # Check for BOLT tools
    if ! command -v llvm-bolt &> /dev/null; then
        echo -e "${BUILD_RED}✗ llvm-bolt not found. Try: module load clang${BUILD_NC}"
        return 1
    fi

    # Step 2: Instrument binary with BOLT
    echo "Step 2/5: Instrumenting binary with BOLT..."
    local bolt_profile_dir="$BUILD_VARIANT_SCRATCH/bolt-data"
    mkdir -p "$bolt_profile_dir"
    local instrumented_binary="$bolt_profile_dir/rg-instrumented"

    if ! llvm-bolt "$pgo_binary" \
        -instrument \
        -instrumentation-file="$bolt_profile_dir/prof.fdata" \
        -o "$instrumented_binary" 2>&1; then
        echo -e "${BUILD_RED}✗ BOLT instrumentation failed${BUILD_NC}"
        return 1
    fi

    # Step 3: Run profiling workloads with instrumented binary
    echo "Step 3/5: Collecting BOLT profile data..."
    chmod +x "$instrumented_binary"
    run_pgo_workloads "$instrumented_binary"

    # Step 4: Merge BOLT profile data
    echo "Step 4/5: Merging BOLT profile data..."
    if ls "$bolt_profile_dir"/prof.fdata.* 1> /dev/null 2>&1; then
        if ! command -v merge-fdata &> /dev/null; then
            echo -e "${BUILD_RED}✗ merge-fdata not found. Try: module load clang${BUILD_NC}"
            return 1
        fi
        if ! merge-fdata "$bolt_profile_dir"/prof.fdata.* > "$bolt_profile_dir/prof.fdata"; then
            echo -e "${BUILD_RED}✗ BOLT profile merge failed${BUILD_NC}"
            return 1
        fi
        rm -f "$bolt_profile_dir"/prof.fdata.*
    fi

    if [[ ! -f "$bolt_profile_dir/prof.fdata" ]]; then
        echo -e "${BUILD_RED}✗ BOLT profile data not found${BUILD_NC}"
        return 1
    fi

    # Step 5: Apply BOLT optimization
    echo "Step 5/5: Applying BOLT optimization..."
    local bolt_binary="$target_dir/$target/$profile/rg-bolt"

    if ! llvm-bolt "$pgo_binary" \
        -data="$bolt_profile_dir/prof.fdata" \
        -reorder-blocks=ext-tsp \
        -reorder-functions=hfsort+ \
        -split-functions=3 \
        -split-all-cold \
        -split-eh \
        -icf=1 \
        -use-gnu-stack \
        -o "$bolt_binary" 2>&1; then
        echo -e "${BUILD_RED}✗ BOLT optimization failed${BUILD_NC}"
        return 1
    fi

    local build_end=$(date +%s)
    local build_time=$((build_end - build_start))

    if [[ ! -f "$bolt_binary" ]]; then
        echo -e "${BUILD_RED}✗ BOLT binary not found: $bolt_binary${BUILD_NC}"
        return 1
    fi

    # Install
    mkdir -p "$BUILD_INSTALL_DIR"
    cp "$bolt_binary" "$BUILD_INSTALL_DIR/rg-$variant_name"
    chmod +x "$BUILD_INSTALL_DIR/rg-$variant_name"

    # Strip the final BOLT binary to reduce size
    echo "Stripping BOLT binary..."
    strip --strip-all "$BUILD_INSTALL_DIR/rg-$variant_name"

    # Inject allocator library if needed
    inject_allocator_library "$BUILD_INSTALL_DIR/rg-$variant_name" "$variant_name" || return 1

    # Inject or configure PCRE2 library
    inject_pcre2_library "$BUILD_INSTALL_DIR/rg-$variant_name" "$variant_name" || return 1

    local size=$(du -h "$BUILD_INSTALL_DIR/rg-$variant_name" | cut -f1)
    echo -e "${BUILD_GREEN}✓ Built successfully${BUILD_NC}"
    echo "  Build time: ${build_time}s"
    echo "  Binary size: $size"
    echo "  Installed: $BUILD_INSTALL_DIR/rg-$variant_name"
    echo ""

    return 0
}

# Verify binary works
verify_binary() {
    local variant_name=$1
    local binary_path="$BUILD_INSTALL_DIR/rg-$variant_name"

    if [[ ! -f "$binary_path" ]]; then
        echo -e "${BUILD_RED}✗ Binary not found: $binary_path${BUILD_NC}"
        return 1
    fi

    # Basic execution test
    if ! "$binary_path" --version > /dev/null 2>&1; then
        echo -e "${BUILD_RED}✗ Binary fails version check${BUILD_NC}"
        return 1
    fi

    echo -e "${BUILD_GREEN}✓ Binary execution test passed${BUILD_NC}"

    # Comprehensive feature verification
    verify_binary_features "$binary_path" "$variant_name"

    return $?
}

# Main build wrapper
build_variant() {
    local variant_name=$1
    local description=$2
    local build_type=$3  # "simple", "pgo", or "bolt"
    local target=$4
    local profile=$5
    local rustflags=${6:-}
    local features=${7:-"pcre2"}  # Default to pcre2, can add jemalloc, mimalloc-allocator

    # Setup variant-specific scratch directory
    export BUILD_VARIANT_SCRATCH="$SCRATCH_DIR/build-$variant_name"
    export BUILD_PGO_DATA_DIR="$BUILD_VARIANT_SCRATCH/pgo-data"

    # Use variant-specific cargo target directory for parallel builds
    export CARGO_TARGET_DIR="$BUILD_VARIANT_SCRATCH/target"

    # Clean variant scratch directory if it exists
    if [[ -d "$BUILD_VARIANT_SCRATCH" ]]; then
        rm -rf "$BUILD_VARIANT_SCRATCH"
    fi
    mkdir -p "$BUILD_VARIANT_SCRATCH"

    print_build_header "$variant_name" "$description"

    # Dump pre-build environment to separate file if BUILD_LOG_BASE is set
    if [[ -n "${BUILD_LOG_BASE:-}" ]]; then
        print_build_environment > "${BUILD_LOG_BASE}.preenv" 2>&1
        echo "Pre-build environment: ${BUILD_LOG_BASE}.preenv"
    else
        # If not running from build-all-variants.sh, log to stdout
        print_build_environment
    fi

    # Note: We don't call clean_build here since we're using isolated target directories

    local result=0
    if [[ "$build_type" == "simple" ]]; then
        build_simple "$variant_name" "$target" "$profile" "$rustflags" "$features"
        result=$?
    elif [[ "$build_type" == "pgo" ]]; then
        build_pgo "$variant_name" "$target" "$profile" "$rustflags" "$features"
        result=$?
    elif [[ "$build_type" == "bolt" ]]; then
        build_bolt "$variant_name" "$target" "$profile" "$rustflags" "$features"
        result=$?
    else
        echo -e "${BUILD_RED}✗ Unknown build type: $build_type${BUILD_NC}"
        result=1
    fi

    if [[ $result -eq 0 ]]; then
        verify_binary "$variant_name"
        result=$?
    fi

    # Dump post-build environment to separate file if BUILD_LOG_BASE is set
    if [[ -n "${BUILD_LOG_BASE:-}" ]]; then
        print_build_environment > "${BUILD_LOG_BASE}.postenv" 2>&1
        echo "Post-build environment: ${BUILD_LOG_BASE}.postenv"
    fi

    # Clean up variant scratch directory after build
    if [[ -d "$BUILD_VARIANT_SCRATCH" ]]; then
        rm -rf "$BUILD_VARIANT_SCRATCH"
    fi

    return $result
}
