# Allocator Optimization Matrix - February 14, 2026

## Overview

Complete matrix of memory allocator variants with all optimization combinations:
- **2 allocators**: jemalloc 5.3.0, mimalloc 2.1.7
- **2 linking modes**: static, dynamic
- **4 optimization levels**: PGO, PGO+v3, BOLT, BOLT+v3

**Total: 16 allocator variants** (2 allocators × 2 linking × 4 optimizations)

## Complete Variant Matrix

### jemalloc Variants (8)

| Variant Name | Optimization | Linking | Size | Description |
|--------------|-------------|---------|------|-------------|
| `rg-lto-pgo-jemalloc-static` | LTO+PGO | Static | 3.8M | Base PGO optimization |
| `rg-lto-pgo-jemalloc-dynamic` | LTO+PGO | Dynamic | 3.8M | Base PGO optimization |
| `rg-lto-pgo-v3-jemalloc-static` | LTO+PGO+AVX2 | Static | ~3.8M | x86-64-v3 with AVX2/BMI2/FMA |
| `rg-lto-pgo-v3-jemalloc-dynamic` | LTO+PGO+AVX2 | Dynamic | ~3.8M | x86-64-v3 with AVX2/BMI2/FMA |
| `rg-lto-pgo-bolt-jemalloc-static` | LTO+PGO+BOLT | Static | ~6-7M | Post-link binary optimization |
| `rg-lto-pgo-bolt-jemalloc-dynamic` | LTO+PGO+BOLT | Dynamic | ~6-7M | Post-link binary optimization |
| `rg-lto-pgo-bolt-v3-jemalloc-static` | LTO+PGO+BOLT+AVX2 | Static | ~6-7M | Maximum optimization + AVX2 |
| `rg-lto-pgo-bolt-v3-jemalloc-dynamic` | LTO+PGO+BOLT+AVX2 | Dynamic | ~6-7M | Maximum optimization + AVX2 |

### mimalloc Variants (8)

| Variant Name | Optimization | Linking | Size | Description |
|--------------|-------------|---------|------|-------------|
| `rg-lto-pgo-mimalloc-static` | LTO+PGO | Static | 3.8M | Base PGO optimization |
| `rg-lto-pgo-mimalloc-dynamic` | LTO+PGO | Dynamic | 3.8M | Base PGO optimization |
| `rg-lto-pgo-v3-mimalloc-static` | LTO+PGO+AVX2 | Static | ~3.8M | x86-64-v3 with AVX2/BMI2/FMA |
| `rg-lto-pgo-v3-mimalloc-dynamic` | LTO+PGO+AVX2 | Dynamic | ~3.8M | x86-64-v3 with AVX2/BMI2/FMA |
| `rg-lto-pgo-bolt-mimalloc-static` | LTO+PGO+BOLT | Static | ~6-7M | Post-link binary optimization |
| `rg-lto-pgo-bolt-mimalloc-dynamic` | LTO+PGO+BOLT | Dynamic | ~6-7M | Post-link binary optimization |
| `rg-lto-pgo-bolt-v3-mimalloc-static` | LTO+PGO+BOLT+AVX2 | Static | ~6-7M | Maximum optimization + AVX2 |
| `rg-lto-pgo-bolt-v3-mimalloc-dynamic` | LTO+PGO+BOLT+AVX2 | Dynamic | ~6-7M | Maximum optimization + AVX2 |

## Optimization Levels Explained

### 1. LTO+PGO (Base)
- **LTO**: Link-Time Optimization - whole-program optimization
- **PGO**: Profile-Guided Optimization - optimizes hot paths based on profiling
- **Expected improvement**: 3-4% over baseline
- **Build time**: ~3-4 minutes per variant

### 2. LTO+PGO+v3 (AVX2)
- Everything from LTO+PGO, plus:
- **x86-64-v3**: Targets modern CPUs (2015+) with AVX2, BMI2, FMA instructions
- **Expected improvement**: +1% over base PGO on modern CPUs
- **Build time**: ~3-4 minutes per variant
- **Requirement**: CPU with AVX2 support

### 3. LTO+PGO+BOLT
- Everything from LTO+PGO, plus:
- **BOLT**: Binary Optimization and Layout Tool - post-link code layout optimization
- **Expected improvement**: +1% over base PGO (dynamic), potentially more with allocators
- **Build time**: ~8-10 minutes per variant (includes instrumentation + profiling)

### 4. LTO+PGO+BOLT+v3 (Maximum)
- Combines all optimizations:
- **LTO + PGO + BOLT + AVX2**
- **Expected improvement**: +5-6% over baseline
- **Build time**: ~8-10 minutes per variant
- **Best for**: Maximum performance on modern CPUs

## Allocator Characteristics

### jemalloc 5.3.0
**Source**: `/tools_soc/opensrc/jemalloc/5.3.0/`

**Strengths:**
- Excellent multi-threaded performance
- Thread-local caching reduces lock contention
- Good at reducing memory fragmentation
- Widely used (Firefox, FreeBSD, Facebook)

**Best for:**
- Large codebases with many threads
- High-concurrency workloads
- Long-running processes

### mimalloc 2.1.7
**Source**: `/tools_soc/opensrc/mimalloc/2.1.7/`

**Strengths:**
- Excellent single-threaded performance
- Very low memory overhead
- Free-list sharding for scalability
- Developed by Microsoft Research

**Best for:**
- Memory-constrained systems
- Single-threaded or lightly-threaded workloads
- Situations where memory overhead matters

## Build Scripts

### Build All Allocator Variants
```bash
# Build all 16 variants (takes 1-2 hours)
./build-allocator-optimized.sh

# Or build specific allocator
./build-jemalloc-all.sh   # All 8 jemalloc variants
./build-mimalloc-all.sh   # All 8 mimalloc variants
```

### Build Specific Variant Manually
```bash
# Example: Build jemalloc BOLT+v3 static
export RUSTFLAGS="-C link-arg=-L/tools_soc/opensrc/jemalloc/5.3.0/lib \
                  -C link-arg=-ljemalloc \
                  -C target-cpu=x86-64-v3 \
                  -C link-arg=-Wl,--emit-relocs"
export JEMALLOC_SYS_WITH_LG_PAGE=16
export FEATURES="pcre2"
CARGO_PROFILE=release-bolt ./build-bolt.sh
cp target/release-bolt/rg /path/to/rg-lto-pgo-bolt-v3-jemalloc-static
```

## Performance Testing

### Expected Performance Hierarchy

**For standard patterns:**
1. `rg-lto-pgo-bolt-v3-{allocator}-*` - Maximum (BOLT+v3)
2. `rg-lto-pgo-bolt-{allocator}-*` - Excellent (BOLT)
3. `rg-lto-pgo-v3-{allocator}-*` - Very good (PGO+v3)
4. `rg-lto-pgo-{allocator}-*` - Good (PGO base)

**Allocator comparison (workload-dependent):**
- **jemalloc**: May be 2-5% faster on multi-threaded workloads
- **mimalloc**: May be 1-3% faster on single-threaded workloads
- **System allocator (glibc)**: Baseline reference

**Linking mode:**
- **Static**: No runtime dependency, slightly larger
- **Dynamic**: Smaller binary, requires .so at runtime

### Quick Comparison
```bash
# Test all allocator variants
./benchmark-quick.sh

# Compare specific optimization levels
hyperfine \
  "rg-lto-pgo-jemalloc-static 'pattern' /large/codebase" \
  "rg-lto-pgo-v3-jemalloc-static 'pattern' /large/codebase" \
  "rg-lto-pgo-bolt-jemalloc-static 'pattern' /large/codebase" \
  "rg-lto-pgo-bolt-v3-jemalloc-static 'pattern' /large/codebase"
```

## Functional Verification

All 16 allocator variants pass the same functional tests:

```bash
./verify-variants-functional.sh
# Tests: 27 total variants × 8 tests = 216 tests
```

Tests include:
1. Version check
2. Literal search
3. Regex patterns
4. Case-insensitive search
5. Count mode
6. Type filtering
7. PCRE2 support
8. Multi-pattern search

## Complete Variant Count

**Total ripgrep variants: 27**

- 3 reference versions (OS, Rust 2025.10.06, Rust 2025.11.23)
- 8 standard optimized builds
- 16 allocator variants (2 allocators × 2 linking × 4 optimizations)

## Naming Convention

Format: `rg-<lto>-<pgo>-<bolt>-<v3>-<allocator>-<linking>`

**Components:**
- `lto` - Always present in optimized variants
- `pgo` - Profile-Guided Optimization
- `bolt` - Binary Optimization and Layout Tool (optional)
- `v3` - x86-64-v3 microarchitecture (optional)
- `allocator` - `jemalloc` or `mimalloc`
- `linking` - `static` or `dynamic`

**Examples:**
- `rg-lto-pgo-jemalloc-static` - Base PGO with static jemalloc
- `rg-lto-pgo-v3-jemalloc-dynamic` - PGO + AVX2 with dynamic jemalloc
- `rg-lto-pgo-bolt-mimalloc-static` - PGO + BOLT with static mimalloc
- `rg-lto-pgo-bolt-v3-mimalloc-dynamic` - All optimizations with dynamic mimalloc

## Use Cases

### Maximum Performance (Modern CPUs)
```bash
rg-lto-pgo-bolt-v3-jemalloc-static    # Best for multi-threaded
rg-lto-pgo-bolt-v3-mimalloc-static    # Best for single-threaded
```

### Good Performance (All CPUs)
```bash
rg-lto-pgo-bolt-jemalloc-static       # Multi-threaded
rg-lto-pgo-bolt-mimalloc-static       # Single-threaded
```

### Balanced (Fast + Small)
```bash
rg-lto-pgo-v3-jemalloc-dynamic        # Small binary, good performance
rg-lto-pgo-v3-mimalloc-dynamic        # Small binary, low overhead
```

### Production Deployment
```bash
# For modern infrastructure (AVX2+)
rg-lto-pgo-bolt-v3-jemalloc-dynamic

# For mixed infrastructure
rg-lto-pgo-bolt-jemalloc-dynamic

# For memory-constrained systems
rg-lto-pgo-mimalloc-dynamic
```

## Build Time Estimates

Per variant:
- PGO variants: ~3-4 minutes
- BOLT variants: ~8-10 minutes

Total for all 16 allocator variants: **~1-2 hours**

## Integration

All allocator variants are automatically included in:
- `verify-variants-functional.sh` - Functional testing
- `benchmark-quick.sh` - Quick performance comparison
- `benchmark-local.sh` - Comprehensive benchmarking

## Future Work

Potential additional testing:
1. Memory consumption analysis
2. Allocator overhead profiling
3. Fragmentation testing under load
4. Long-running stability tests
5. tcmalloc comparison (Google's allocator)

## Summary

Created comprehensive allocator testing matrix with 16 variants covering:
- 2 allocators (jemalloc, mimalloc)
- 2 linking modes (static, dynamic)
- 4 optimization levels (PGO, PGO+v3, BOLT, BOLT+v3)

All variants built with consistent optimization base (LTO+PGO) for fair comparison. Testing will reveal which allocator and optimization combination provides best performance for ripgrep's I/O-heavy workload.
