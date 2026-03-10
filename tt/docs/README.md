# Ripgrep Optimization Scripts and Documentation

This directory contains all generated scripts, documentation, and test results for the ripgrep optimization project.

## Quick Start

Start here: **[INDEX.md](INDEX.md)** - Central navigation for all resources

Or jump to: **[BUILD_AND_BENCHMARK_SUMMARY.md](BUILD_AND_BENCHMARK_SUMMARY.md)** - Complete project summary

## Directory Contents

### Build Scripts
- `build-all-variants.sh` - Build all 6 ripgrep variants
- `build-pgo.sh` - Build PGO-optimized variant
- `build-musl.sh` - Build static MUSL variant
- `build-bolt.sh` - Build BOLT-optimized variant (LTO+PGO+BOLT)
- `build-bolt-pcre2-jit.sh` - Build BOLT with static PCRE2 JIT (+8% on PCRE2)
- `build-jemalloc.sh` - Build jemalloc allocator variants (static + dynamic)
- `build-mimalloc.sh` - Build mimalloc allocator variants (static + dynamic)
- `install-optimized.sh` - Installation helper

### Benchmark Scripts
- `benchmark-quick.sh` - Fast 2-minute comparison (recommended)
- `benchmark-local.sh` - Comprehensive 8-test suite (~15 min)
- `benchmark-all-hosts.sh` - Distributed benchmarking (~30 min)
- `benchmark-large-datasets.sh` - Large-scale benchmarks on 288GB+ datasets (~variable time)

### Verification & Testing
- `verify-variants-functional.sh` - **Functional verification of all variants** (recommended, ~1 min)
- `verify-all-variants.sh` - Quick version check of all binaries
- `test-rg-all-hosts.sh` - Test across infrastructure hosts
- `test-pgo-on-hosts.sh` - PGO variant infrastructure testing
- `parallel-test-hosts.sh` - Parallel host testing
- `quick-test-hosts.sh` - Quick host validation
- `test-optimizations.sh` - Optimization testing
- `check-cpu-v3-support.sh` - Check AVX2/x86-64-v3 support

### Documentation

#### Getting Started
- **INDEX.md** - Central navigation and quick reference
- **README_OPTIMIZATIONS.md** - Quick start guide
- **BUILD_AND_BENCHMARK_SUMMARY.md** - Complete project overview

#### Technical Details
- **COMPREHENSIVE_VARIANT_TESTING.md** - Complete testing framework and verification results
- **BENCHMARKING_GUIDE.md** - Comprehensive benchmarking guide
- **OPTIMIZATION.md** - Technical optimization details
- **OPTIMIZATION_SUMMARY.md** - Executive summary
- **BOLT_VARIANT.md** - BOLT optimization guide (advanced)
- **BOLT_STATIC_ANALYSIS.md** - Static vs dynamic linking analysis (+8% with static PCRE2)

#### Testing & Results
- **HOST_COMPATIBILITY_REPORT.md** - Infrastructure testing results
- **COMPREHENSIVE_TEST_REPORT.md** - Full test report
- **CPU_V3_COMPATIBILITY_ANALYSIS.md** - x86-64-v3 compatibility analysis

#### Integration
- **TTCONJURER_INTEGRATION.md** - ttconjurer integration guide

### Result Directories
- `benchmark-results/` - Local benchmark outputs (created at runtime)
- `benchmark-results-distributed/` - Distributed benchmark outputs (created at runtime)
- `test-results/` - Test results from host testing
- `test-results-extended/` - Extended test results
- `cpu-v3-results/` - CPU v3 compatibility test results
- `pgo-test-results.txt` - PGO test results
- `pgo-test-failed.txt` - Failed PGO tests

## Quick Commands

```bash
# Build all variants
./build-all-variants.sh

# Verify builds work
./verify-all-variants.sh

# Quick benchmark (~2 min)
./benchmark-quick.sh

# Comprehensive benchmarks (~15 min)
./benchmark-local.sh

# Test across all hosts (~30 min)
./benchmark-all-hosts.sh
```

## Binary Locations

All built binaries are installed to: `/proj_soc/user_dev/gczajkowski/bin/`

### Reference Versions (for comparison)
- `rg-os` - OS provided (14.1.1 from /usr/bin/rg, 4.9M)
- `rg-2025.10.06` - Rust 2025.10.06 (14.1.1, 4.5M)
- `rg-2025.11.23` - Rust 2025.11.23 (15.1.0, 4.5M)

### Optimized Builds
- `rg-lto-pgo-bolt-static-pcre2` - **Ultimate** (LTO+PGO+BOLT+static PCRE2, 8.9M, +8% on PCRE2)
- `rg-lto-pgo-bolt-dynamic` - **Maximum** (LTO+PGO+BOLT, 6.9M, +1% over PGO)
- `rg-lto-pgo-v3-dynamic` - Fastest standard (PGO + AVX2, 3.8M)
- `rg-lto-pgo-dynamic` - Best overall (PGO, 3.7M)
- `rg-lto` - Balanced (LTO, 4.1M)
- `rg-lto-musl` - Portable (static, 5.2M)
- `rg-lto-musl-v3` - Portable + fast (static + AVX2, 5.2M)
- `rg-baseline` - Baseline (29M)

### Allocator Variants (16 total)

**jemalloc (8 variants):**
- `rg-lto-pgo-jemalloc-static` / `rg-lto-pgo-jemalloc-dynamic` - Base LTO+PGO
- `rg-lto-pgo-v3-jemalloc-static` / `rg-lto-pgo-v3-jemalloc-dynamic` - LTO+PGO+AVX2
- `rg-lto-pgo-bolt-jemalloc-static` / `rg-lto-pgo-bolt-jemalloc-dynamic` - LTO+PGO+BOLT
- `rg-lto-pgo-bolt-v3-jemalloc-static` / `rg-lto-pgo-bolt-v3-jemalloc-dynamic` - LTO+PGO+BOLT+AVX2

**mimalloc (8 variants):**
- `rg-lto-pgo-mimalloc-static` / `rg-lto-pgo-mimalloc-dynamic` - Base LTO+PGO
- `rg-lto-pgo-v3-mimalloc-static` / `rg-lto-pgo-v3-mimalloc-dynamic` - LTO+PGO+AVX2
- `rg-lto-pgo-bolt-mimalloc-static` / `rg-lto-pgo-bolt-mimalloc-dynamic` - LTO+PGO+BOLT
- `rg-lto-pgo-bolt-v3-mimalloc-static` / `rg-lto-pgo-bolt-v3-mimalloc-dynamic` - LTO+PGO+BOLT+AVX2

## Performance Summary

Quick benchmark on AMD EPYC 9455:
- **rg-lto-pgo-v3-dynamic**: 595.6ms (fastest)
- **rg-lto-pgo-dynamic**: 606.7ms (+1.9%)
- **rg-baseline**: 613.6ms (+3.0%)
- **rg-lto**: 617.5ms (+3.7%)

**Key improvements:**
- 3-4% faster than standard builds
- 82-87% smaller binaries (3.7-5.2MB vs 29MB)
- 100% SOC infrastructure compatibility

## Recommendations

- **Maximum Performance (PCRE2):** `rg-lto-pgo-bolt-static-pcre2` (LTO+PGO+BOLT+static PCRE2, +8% on PCRE2 patterns)
- **Maximum Performance (standard):** `rg-bolt` (LTO+PGO+BOLT, +1% over PGO)
- **Production (modern):** `rg-lto-pgo-v3-dynamic` (fastest standard build, AVX2 optimized)
- **Production (mixed):** `rg-pgo` (best compatibility + speed)
- **CentOS 7 / Legacy:** `rg-musl` (static, GLIBC-independent)
- **Development:** `rg-lto` (fast build, good performance)

## Requirements

### For Building
- Rust 1.85+ with `llvm-tools-preview`
- PCRE2 library
- MUSL toolchain (auto-downloaded by scripts)

### For Benchmarking
- `hyperfine` - Install: `cargo install hyperfine`
- SSH access to infrastructure hosts
- Access to `/proj_soc/user_dev/socinfra/resource_summary.json`

## Project Information

- **Project Location:** `/proj_soc/user_dev/gczajkowski/ripgrepTT/`
- **Binary Location:** `/proj_soc/user_dev/gczajkowski/bin/`
- **Build Date:** February 14, 2026
- **Build Host:** soc-l-10 (AMD EPYC 9455)
- **ripgrep Version:** 15.1.0 (rev 83a84fb0bd)

---

For detailed information, see **[INDEX.md](INDEX.md)** or **[BUILD_AND_BENCHMARK_SUMMARY.md](BUILD_AND_BENCHMARK_SUMMARY.md)**
