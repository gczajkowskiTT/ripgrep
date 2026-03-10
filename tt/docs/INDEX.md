# Ripgrep Optimization Project - Index

Central index for all documentation, scripts, and resources.

## Quick Links

- **[BUILD_AND_BENCHMARK_SUMMARY.md](BUILD_AND_BENCHMARK_SUMMARY.md)** - **START HERE** - Complete project summary
- **[BENCHMARKING_GUIDE.md](BENCHMARKING_GUIDE.md)** - Comprehensive benchmarking guide
- **[OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md)** - Executive optimization summary

## Project Overview

**Goal:** Build and benchmark optimized ripgrep variants for maximum performance across SOC infrastructure

**Status:** ✓ Complete - 6 variants built, tested, and benchmarked

**Results:** pgo-v3 variant is 3% faster with 87% smaller binary size

## Built Binaries

Location: `/proj_soc/user_dev/gczajkowski/bin/`

| Binary | Size | Performance | Use Case |
|--------|------|-------------|----------|
| rg-pgo-v3 | 3.8M | Fastest (595ms) | Modern CPUs (recommended) |
| rg-pgo | 3.7M | Very fast (607ms) | Best compatibility |
| rg-lto | 4.1M | Fast (617ms) | Development |
| rg-musl | 5.2M | Fast | CentOS 7 / portable |
| rg-musl-v3 | 5.2M | Fastest | Portable + modern CPUs |
| rg-standard | 29M | Baseline (614ms) | Comparison only |

## Documentation Structure

### Getting Started
1. **[BUILD_AND_BENCHMARK_SUMMARY.md](BUILD_AND_BENCHMARK_SUMMARY.md)** - Complete project overview
2. **[README_OPTIMIZATIONS.md](README_OPTIMIZATIONS.md)** - Quick start guide
3. **[BENCHMARKING_GUIDE.md](BENCHMARKING_GUIDE.md)** - How to benchmark

### Technical Details
- **[OPTIMIZATION.md](OPTIMIZATION.md)** - In-depth optimization techniques
- **[OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md)** - Executive summary
- **[CPU_V3_COMPATIBILITY_ANALYSIS.md](CPU_V3_COMPATIBILITY_ANALYSIS.md)** - x86-64-v3 analysis

### Testing & Compatibility
- **[HOST_COMPATIBILITY_REPORT.md](HOST_COMPATIBILITY_REPORT.md)** - Infrastructure testing
- **[COMPREHENSIVE_TEST_REPORT.md](COMPREHENSIVE_TEST_REPORT.md)** - Full test results

### Integration
- **[TTCONJURER_INTEGRATION.md](TTCONJURER_INTEGRATION.md)** - ttconjurer integration guide

## Scripts Reference

### Build Scripts

```bash
# Build all 6 variants (recommended)
./build-all-variants.sh

# Build specific variants
./build-pgo.sh          # PGO variant only
./build-musl.sh         # MUSL variant only
```

### Benchmark Scripts

```bash
# Quick benchmark (~2 minutes)
./benchmark-quick.sh

# Comprehensive local benchmarks (~15 minutes)
./benchmark-local.sh

# Distributed benchmarks across all hosts (~30 minutes)
./benchmark-all-hosts.sh
```

### Verification Scripts

```bash
# Verify all variants work correctly
./verify-all-variants.sh
```

### Test Scripts (Legacy)

```bash
# Quick functionality test
./quick-test-hosts.sh

# Parallel testing across hosts
./parallel-test-hosts.sh

# Full infrastructure test
./test-rg-all-hosts.sh
```

## Common Tasks

### I want to build optimized ripgrep

```bash
cd /proj_soc/user_dev/gczajkowski/ripgrepTT
./build-all-variants.sh
```

**Output:** All binaries in `/proj_soc/user_dev/gczajkowski/bin/`

### I want to benchmark variants locally

```bash
# Quick comparison
./benchmark-quick.sh

# Comprehensive suite
./benchmark-local.sh
```

**Output:** Results in `benchmark-results/`

### I want to test across all infrastructure

```bash
./benchmark-all-hosts.sh
```

**Output:** Results in `benchmark-results-distributed/`

### I want to verify builds work

```bash
./verify-all-variants.sh
```

### I want to use the fastest variant

```bash
# Use pgo-v3 (fastest on modern CPUs)
/proj_soc/user_dev/gczajkowski/bin/rg-pgo-v3 "search pattern" /path/to/search

# Or add to PATH
export PATH="/proj_soc/user_dev/gczajkowski/bin:$PATH"
alias rg='rg-pgo-v3'
```

### I want to deploy to a CentOS 7 host

```bash
# Use MUSL static binary (no GLIBC dependency)
scp /proj_soc/user_dev/gczajkowski/bin/rg-musl user@centos7-host:/usr/local/bin/rg
```

### I want to integrate with ttconjurer

See **[TTCONJURER_INTEGRATION.md](TTCONJURER_INTEGRATION.md)**

Already configured in `/proj_soc/user_dev/gczajkowski/ttconjurer/rust/install.bash`

## Results Summary

### Performance (on AMD EPYC 9455)

```
pgo-v3     595.6ms  ★★★★★  (fastest)
pgo        606.7ms  ★★★★☆
standard   613.6ms  ★★★☆☆
lto        617.5ms  ★★★☆☆
```

### Binary Sizes

```
pgo        3.7M  ★★★★★  (smallest optimized)
pgo-v3     3.8M  ★★★★★
lto        4.1M  ★★★★☆
musl       5.2M  ★★★☆☆
musl-v3    5.2M  ★★★☆☆
standard    29M  ★☆☆☆☆  (7.8x larger!)
```

### Portability

```
musl       ★★★★★  (static, any GLIBC)
musl-v3    ★★★★★  (static, modern CPUs)
pgo        ★★★★☆  (GLIBC 2.28+)
lto        ★★★★☆  (GLIBC 2.28+)
pgo-v3     ★★★☆☆  (GLIBC 2.28+, AVX2)
standard   ★★★★☆  (GLIBC 2.28+)
```

## Recommendations by Use Case

| Use Case | Recommended Variant | Why |
|----------|---------------------|-----|
| **Production (modern infrastructure)** | `rg-pgo-v3` | Fastest, 100% SOC host compatibility |
| **Production (mixed infrastructure)** | `rg-pgo` | Best balance of speed + compatibility |
| **CentOS 7 / Legacy systems** | `rg-musl` | Static binary, GLIBC-independent |
| **Development builds** | `rg-lto` | Fast build time, good performance |
| **Maximum portability** | `rg-musl-v3` | Static + optimized |

## Configuration Files

- **[Cargo.toml](Cargo.toml)** - Rust build configuration with optimization profiles
- **[.cargo/config.toml](.cargo/config.toml)** - Cargo configuration (CPU opts commented)

## Results Directories

```
benchmark-results/              # Local benchmark outputs
benchmark-results-distributed/  # Distributed benchmark outputs
test-results/                   # Legacy test results
test-results-extended/          # Extended test results
cpu-v3-results/                 # x86-64-v3 compatibility results
```

## Key Features

All variants include:
- ✓ PCRE2 support with JIT compilation
- ✓ SSE2 runtime detection
- ✓ SSSE3 runtime detection
- ✓ AVX2 runtime detection
- ✓ AVX2 compile-time optimization (v3 variants only)

## Requirements

### For Building
- Rust 1.85+ with `llvm-tools-preview`
- PCRE2 library
- MUSL toolchain (auto-downloaded)

### For Benchmarking
- `hyperfine` - Install: `cargo install hyperfine`
- SSH access to infrastructure hosts
- Access to `/proj_soc/user_dev/socinfra/resource_summary.json`

## Troubleshooting

### Build Issues

**PGO build fails:**
```bash
rustup component add llvm-tools-preview
```

**MUSL build fails:**
- Script auto-downloads toolchain to `/tmp/`
- Check `/tmp/x86_64-linux-musl-cross/`

### Benchmark Issues

**hyperfine not found:**
```bash
cargo install hyperfine
export PATH="$HOME/.cargo/bin:$PATH"
```

**Hosts unreachable:**
- Check SSH access: `ssh -o ConnectTimeout=5 host hostname`
- Check /proj_soc mounted: `ssh host ls /proj_soc/user_dev/`
- Belgrade hosts may need different approach (no /proj_soc)

### Runtime Issues

**GLIBC version error:**
- Use MUSL variants (`rg-musl` or `rg-musl-v3`)
- Static binaries work on any GLIBC version

**Illegal instruction (SIGILL):**
- Don't use v3 variants on old CPUs
- Use standard variants instead
- All SOC infrastructure hosts support v3 (verified)

## Contact & Support

- Review documentation in this directory
- Check benchmark results in `benchmark-results/`
- Verify builds: `./verify-all-variants.sh`
- Test on infrastructure: `./benchmark-all-hosts.sh`

## Version Information

- **ripgrep version:** 15.1.0 (rev 83a84fb0bd)
- **Build date:** February 14, 2026
- **Build host:** soc-l-10 (AMD EPYC 9455)
- **Rust version:** 1.85+

## License

Same as upstream ripgrep (MIT/Unlicense)

---

**Last updated:** February 14, 2026
**Project location:** `/proj_soc/user_dev/gczajkowski/ripgrepTT`
**Binary location:** `/proj_soc/user_dev/gczajkowski/bin/`
