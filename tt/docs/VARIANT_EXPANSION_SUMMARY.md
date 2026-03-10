# Variant Expansion - BOLT and v3 on Allocators

## Date
February 14, 2026

## Overview

Expanded allocator testing framework by adding BOLT and v3 (AVX2) optimizations on top of all allocator variants.

**Original**: 4 allocator variants (2 allocators × 2 linking modes × 1 optimization level)
**New**: 16 allocator variants (2 allocators × 2 linking modes × 4 optimization levels)
**Added**: 12 new variants

## New Variants Added (12)

### jemalloc (6 new)
1. `rg-lto-pgo-v3-jemalloc-static` - PGO + AVX2, static linking
2. `rg-lto-pgo-v3-jemalloc-dynamic` - PGO + AVX2, dynamic linking
3. `rg-lto-pgo-bolt-jemalloc-static` - PGO + BOLT, static linking
4. `rg-lto-pgo-bolt-jemalloc-dynamic` - PGO + BOLT, dynamic linking
5. `rg-lto-pgo-bolt-v3-jemalloc-static` - PGO + BOLT + AVX2, static linking
6. `rg-lto-pgo-bolt-v3-jemalloc-dynamic` - PGO + BOLT + AVX2, dynamic linking

### mimalloc (6 new)
7. `rg-lto-pgo-v3-mimalloc-static` - PGO + AVX2, static linking
8. `rg-lto-pgo-v3-mimalloc-dynamic` - PGO + AVX2, dynamic linking
9. `rg-lto-pgo-bolt-mimalloc-static` - PGO + BOLT, static linking
10. `rg-lto-pgo-bolt-mimalloc-dynamic` - PGO + BOLT, dynamic linking
11. `rg-lto-pgo-bolt-v3-mimalloc-static` - PGO + BOLT + AVX2, static linking
12. `rg-lto-pgo-bolt-v3-mimalloc-dynamic` - PGO + BOLT + AVX2, dynamic linking

## Complete Variant Count

**Total: 27 variants**

### Breakdown by Category
- **Reference** (3): OS, Rust 2025.10.06, Rust 2025.11.23
- **Standard optimized** (8): baseline, LTO, PGO, MUSL, v3, BOLT, static PCRE2
- **Allocator variants** (16): 8 jemalloc + 8 mimalloc

### Allocator Variant Matrix (16)

|  | jemalloc (static) | jemalloc (dynamic) | mimalloc (static) | mimalloc (dynamic) |
|---|---|---|---|---|
| **PGO** | ✓ | ✓ | ✓ | ✓ |
| **PGO+v3** | ✓ | ✓ | ✓ | ✓ |
| **PGO+BOLT** | ✓ | ✓ | ✓ | ✓ |
| **PGO+BOLT+v3** | ✓ | ✓ | ✓ | ✓ |

## Build Process

### New Build Scripts
- `build-allocator-optimized.sh` - Builds all 12 new variants (skips existing base PGO)
- `build-jemalloc-all.sh` - Builds all 8 jemalloc variants
- `build-mimalloc-all.sh` - Builds all 8 mimalloc variants

### Build Configuration

**For v3 variants:**
```bash
RUSTFLAGS="-C target-cpu=x86-64-v3 + allocator flags"
CARGO_PROFILE=release-lto
```

**For BOLT variants:**
```bash
RUSTFLAGS="-C link-arg=-Wl,--emit-relocs + allocator flags"
CARGO_PROFILE=release-bolt
```

**For BOLT+v3 variants:**
```bash
RUSTFLAGS="-C target-cpu=x86-64-v3 -C link-arg=-Wl,--emit-relocs + allocator flags"
CARGO_PROFILE=release-bolt
```

### Build Time
- **PGO variants**: ~3-4 minutes each
- **BOLT variants**: ~8-10 minutes each
- **Total for 12 variants**: ~1-2 hours

## Testing Framework Updates

### Updated Scripts
1. `verify-variants-functional.sh` - Now tests 27 variants (216 total tests)
2. `benchmark-quick.sh` - Includes all allocator variants
3. `benchmark-local.sh` - Includes all allocator variants

### Verification
All variants undergo 8 functional tests:
- Version check
- Literal search
- Regex patterns
- Case-insensitive search
- Count mode
- Type filtering
- PCRE2 support
- Multi-pattern search

## Documentation

### New Documentation
- `ALLOCATOR_MATRIX.md` - Complete allocator optimization matrix
- `VARIANT_EXPANSION_SUMMARY.md` - This file

### Updated Documentation
- `README.md` - Updated allocator variants section
- `COMPREHENSIVE_VARIANT_TESTING.md` - Updated for 27 variants
- `ALLOCATOR_VARIANTS.md` - Referenced new optimization levels

## Performance Expectations

### Optimization Stack Impact
Based on standard variant performance:

1. **Base PGO**: +3-4% over baseline
2. **PGO + v3**: +4-5% over baseline (+1% from AVX2)
3. **PGO + BOLT**: +4-5% over baseline (+1% from BOLT)
4. **PGO + BOLT + v3**: +5-6% over baseline (combined benefit)

### Allocator Impact (workload-dependent)
- **jemalloc**: Potentially +2-5% on multi-threaded workloads
- **mimalloc**: Potentially +1-3% on single-threaded workloads

### Combined Expectations
Best case (BOLT+v3 with optimal allocator):
- **Total improvement**: +7-11% over baseline
- **Compared to system ripgrep**: Potentially +10-15%

## Use Cases by Variant

### Maximum Performance
```bash
# For multi-threaded workloads on modern CPUs
rg-lto-pgo-bolt-v3-jemalloc-static

# For single-threaded workloads on modern CPUs
rg-lto-pgo-bolt-v3-mimalloc-static
```

### Balanced Performance (All CPUs)
```bash
# Good performance without AVX2 requirement
rg-lto-pgo-bolt-jemalloc-dynamic
rg-lto-pgo-bolt-mimalloc-dynamic
```

### Small Binary + Good Performance
```bash
# Smaller binaries with PGO+v3
rg-lto-pgo-v3-jemalloc-dynamic  # 3.8M
rg-lto-pgo-v3-mimalloc-dynamic  # 3.8M
```

### Static Linking (No Dependencies)
```bash
# BOLT variants with static allocators
rg-lto-pgo-bolt-jemalloc-static    # ~6-7M
rg-lto-pgo-bolt-mimalloc-static    # ~6-7M
```

## Binary Size Comparison

| Optimization Level | Approximate Size |
|-------------------|------------------|
| PGO base | 3.7-3.8M |
| PGO + v3 | 3.8M |
| PGO + BOLT | 6-7M |
| PGO + BOLT + v3 | 6-7M |

BOLT variants are larger due to:
- Preserved relocations (--emit-relocs)
- Additional BOLT metadata
- Optimized code layout

## Rationale

### Why Add BOLT to Allocators?
1. **Cross-boundary optimization**: BOLT can optimize code layout across ripgrep + allocator
2. **Allocator hot paths**: Memory allocation is in the hot path for ripgrep
3. **Combined benefit**: BOLT + optimized allocator may show synergy

### Why Add v3 to Allocators?
1. **SIMD benefits**: AVX2 instructions may benefit allocator operations
2. **Modern CPUs**: Most infrastructure CPUs support AVX2 (2015+)
3. **Minimal downside**: +1% improvement with no major trade-offs

### Why All Combinations?
1. **Comprehensive testing**: Determine best combination empirically
2. **Workload diversity**: Different workloads may favor different combinations
3. **Architecture comparison**: Static vs dynamic linking with different optimizations

## Next Steps

1. **Complete builds**: Wait for all 12 variants to finish building (~1-2 hours)
2. **Functional verification**: Run `./verify-variants-functional.sh`
3. **Performance testing**: Run `./benchmark-quick.sh` and `./benchmark-local.sh`
4. **Analysis**: Compare allocator + optimization combinations
5. **Deployment**: Select best variants for production use

## Build Status

**Started**: February 14, 2026, 23:32
**In Progress**: Building variant 2/12
**Estimated Completion**: ~1-2 hours

## Integration Complete

All infrastructure updated to support 27 total variants:
- ✓ Build scripts created
- ✓ Testing scripts updated
- ✓ Documentation created
- ✓ Naming convention established
- ⏳ Builds in progress

## Summary

Successfully expanded ripgrep variant testing from 15 to 27 variants by adding BOLT and v3 optimizations to all allocator combinations. This creates a comprehensive testing matrix to determine optimal allocator + optimization combination for ripgrep's workload.

**Key Achievement**: Complete optimization matrix for memory allocator testing with 16 allocator variants covering all meaningful combinations of allocator, linking mode, and optimization level.
