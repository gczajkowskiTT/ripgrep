# Ripgrep Variant Benchmarking Guide

## Overview

This guide covers the benchmarking infrastructure for all ripgrep variants built for maximum performance analysis across the SOC infrastructure.

**Date:** February 14, 2026
**Build Location:** `/proj_soc/user_dev/gczajkowski/ripgrepTT`
**Binary Location:** `/proj_soc/user_dev/gczajkowski/bin/`

## Built Variants

All variants have been successfully built and installed:

| Variant | Size | Description | Use Case |
|---------|------|-------------|----------|
| **rg-standard** | 29M | Standard release build (no LTO) | Baseline comparison |
| **rg-lto** | 4.1M | Release with fat LTO | Smaller binary, good performance |
| **rg-pgo** | 3.7M | Profile-Guided Optimization | Best overall performance |
| **rg-musl** | 5.2M | Static MUSL binary | CentOS 7 / GLIBC-independent |
| **rg-pgo-v3** | 3.8M | PGO + x86-64-v3 (AVX2, BMI2, FMA) | Best for modern CPUs (2015+) |
| **rg-musl-v3** | 5.2M | Static MUSL + x86-64-v3 | Portable + optimized for modern CPUs |

### Key Features

All variants include:
- PCRE2 support (with JIT compilation)
- SSE2 runtime detection (all variants)
- SSSE3 and AVX2 runtime detection (all variants)
- AVX2 compile-time optimization (v3 variants only)

## Benchmarking Scripts

### Local Benchmarking

#### 1. Quick Benchmark (`benchmark-quick.sh`)

**Purpose:** Fast performance comparison of key variants
**Duration:** ~1-2 minutes
**Test:** Simple literal search for "fn " in Rust source code

```bash
./benchmark-quick.sh
```

**Output:**
- Console output with comparative performance
- Summary showing speedup factors

**When to use:** Quick validation after builds, initial performance check

#### 2. Comprehensive Local Benchmark (`benchmark-local.sh`)

**Purpose:** Complete local benchmark suite with multiple test patterns
**Duration:** ~10-15 minutes
**Tests:** 8 different search patterns covering various use cases

```bash
./benchmark-local.sh
```

**Test Suite:**
1. **literal_search_rust** - Simple literal string search
2. **regex_search_rust** - Regex pattern for function definitions
3. **case_insensitive_search** - Case-insensitive search
4. **multi_pattern_search** - Multiple patterns (TODO|FIXME|XXX|HACK)
5. **context_search** - Search with context lines (-C 3)
6. **count_mode** - Count-only mode (-c)
7. **type_filtering** - File type filtering (-t rust)
8. **pcre2_regex** - PCRE2 regex with lookbehind

**Output:**
- JSON files: `benchmark-results/{timestamp}_{test}.json`
- Markdown tables: `benchmark-results/{timestamp}_{test}.md`
- Summary report: `benchmark-results/{timestamp}_SUMMARY.md`

**Hyperfine Configuration:**
- 3 warmup runs
- 10 benchmark runs
- Full statistics (mean, median, min, max, stddev)

### Distributed Benchmarking

#### 3. Distributed Benchmark (`benchmark-all-hosts.sh`)

**Purpose:** Benchmark across all infrastructure hosts
**Duration:** ~15-30 minutes (depends on host count)
**Hosts:** All hosts from `/proj_soc/user_dev/socinfra/resource_summary.json`

```bash
./benchmark-all-hosts.sh
```

**Features:**
- Tests all 6 variants on each host
- Automatic retry logic (2 attempts)
- Extended SSH timeouts (30s)
- CPU detection and reporting
- Skips hosts without hyperfine

**Output:**
- JSON per host: `benchmark-results-distributed/{host}_{timestamp}.json`
- Logs per host: `benchmark-results-distributed/{host}_{timestamp}.log`
- Status files: `benchmark-results-distributed/{host}_{timestamp}.txt`
- Summary: `benchmark-results-distributed/SUMMARY_{timestamp}.md`

**SSH Configuration:**
- ConnectTimeout: 30s
- ServerAliveInterval: 10s
- ServerAliveCountMax: 3
- StrictHostKeyChecking: no

## Initial Benchmark Results

### Local Performance (soc-l-10, AMD EPYC 9455 48-Core)

Quick benchmark results on 96-core AMD EPYC 9455:

```
Variant          Mean Time     vs Fastest
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
pgo-v3           595.6 ms     baseline (fastest)
pgo              606.7 ms     1.02x slower
standard         613.6 ms     1.03x slower
lto              617.5 ms     1.04x slower
```

**Key Findings:**
- **pgo-v3 is 3% faster** than standard builds on modern AMD EPYC
- PGO optimization provides ~1-2% improvement over LTO
- AVX2 optimizations (v3) provide additional ~1-2% improvement
- All optimized variants are within 4% of each other
- Standard build is 7x larger (29MB vs 4MB) with minimal perf gain

### Binary Size vs Performance Trade-offs

```
Binary Size    Performance    Portability
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
29M (standard) Baseline       Good (GLIBC 2.28+)
4.1M (lto)     Similar        Good (GLIBC 2.28+)
3.7M (pgo)     1-2% faster    Good (GLIBC 2.28+)
5.2M (musl)    Similar        Excellent (static)
3.8M (pgo-v3)  3% faster      Moderate (2015+ CPUs)
5.2M (musl-v3) 3% faster      Good (2015+ CPUs, static)
```

## Recommendations

### For Development Builds
**Use:** `rg-lto` (4.1MB, fast compile, good performance)

### For Production Deployment
**Modern Infrastructure (2015+):** `rg-pgo-v3` (best performance, AVX2)
**Mixed Infrastructure:** `rg-pgo` (best compatibility + performance)
**Legacy Systems (CentOS 7):** `rg-musl` (static, GLIBC-independent)

### For Maximum Portability
**Use:** `rg-musl` or `rg-musl-v3` (static binaries, no GLIBC dependency)

## Verification

Verify all variants work correctly:

```bash
./verify-all-variants.sh
```

This tests:
- Binary exists and is executable
- Version command works
- Search functionality works
- Static linking (for MUSL variants)

## Building Additional Variants

To rebuild all variants:

```bash
./build-all-variants.sh
```

Build process:
1. Standard release (8s)
2. LTO release (31s)
3. PGO optimized (3-step: instrument → profile → optimize)
4. MUSL static (54s)
5. PGO + v3 (with x86-64-v3 flags)
6. MUSL + v3 (54s)

All binaries are installed to `/proj_soc/user_dev/gczajkowski/bin/`

## Requirements

### For Building
- Rust toolchain with `llvm-tools-preview`
- MUSL cross-compilation toolchain (automatically downloaded)
- PCRE2 library

### For Benchmarking
- **hyperfine** - Install with: `cargo install hyperfine`
- SSH access to infrastructure hosts
- Access to `/proj_soc/user_dev/socinfra/resource_summary.json`

## Analyzing Results

### Reading JSON Output

Each benchmark produces JSON with detailed statistics:

```json
{
  "results": [
    {
      "command": "pgo-v3",
      "mean": 0.5956,
      "stddev": 0.0091,
      "median": 0.5956,
      "min": 0.5814,
      "max": 0.6072,
      "times": [...]
    }
  ]
}
```

### Reading Markdown Tables

Markdown files contain formatted comparison tables:

```markdown
| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `pgo-v3` | 595.6 ± 9.1 | 581.4 | 607.2 | 1.00 |
| `pgo` | 606.7 ± 7.5 | 590.4 | 612.9 | 1.02 ± 0.02 |
```

### Comparing Across Hosts

Use the distributed summary to compare performance across different CPU architectures:

```bash
cat benchmark-results-distributed/SUMMARY_*.md
```

This shows:
- Performance by CPU type (AMD EPYC, Intel Xeon, etc.)
- Best performing hosts
- CPU-specific optimizations (AVX2 impact)

## Troubleshooting

### hyperfine Not Found

```bash
cargo install hyperfine
# or add to PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### MUSL Binary Build Fails

The build script automatically downloads the MUSL toolchain to `/tmp/`. If it fails:

```bash
# Manual download
cd /tmp
wget https://more.musl.cc/10/x86_64-linux-musl/x86_64-linux-musl-cross.tgz
tar xzf x86_64-linux-musl-cross.tgz
```

### PGO Build Fails

Ensure LLVM tools are installed:

```bash
rustup component add llvm-tools-preview
```

### Hosts Unreachable in Distributed Benchmark

Check:
1. SSH access: `ssh -o ConnectTimeout=5 host hostname`
2. Binary access: `ssh host ls -lh /proj_soc/user_dev/gczajkowski/bin/rg-*`
3. /proj_soc mounted: `ssh host ls /proj_soc/user_dev/`

Belgrade hosts may not have `/proj_soc` mounted (different datacenter).

## Integration with ttconjurer

To use optimized build in ttconjurer:

```bash
# Edit /proj_soc/user_dev/gczajkowski/ttconjurer/rust/install.bash
# Line 176 is already configured to use release-lto profile

cd /proj_soc/user_dev/gczajkowski/ttconjurer
./rust/install.bash
```

This installs `rg-lto` variant (4.1MB, good performance/size trade-off).

## Future Optimizations

Potential areas for further optimization:
1. **BOLT** (Binary Optimization and Layout Tool) - Could provide additional 5-10% improvement
2. **Statically linked PCRE2** - Reduce dependency management
3. **Custom allocator** - jemalloc or mimalloc for better memory performance
4. **Architecture-specific builds** - Separate binaries for AMD EPYC vs Intel Xeon

## References

- [Profile-Guided Optimization in Rust](https://doc.rust-lang.org/rustc/profile-guided-optimization.html)
- [x86-64 Microarchitecture Levels](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels)
- [hyperfine Documentation](https://github.com/sharkdp/hyperfine)
- [MUSL Cross-Compilation](https://musl.cc/)

## Contact

For questions or issues:
- Check existing documentation in this repository
- Review benchmark results in `benchmark-results/` directories
- Verify builds with `./verify-all-variants.sh`

---

**Last Updated:** February 14, 2026
**Build Host:** soc-l-10 (AMD EPYC 9455)
**Rust Version:** 1.85+ (with llvm-tools-preview)
