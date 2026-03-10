# Ripgrep Variant Renaming - February 14, 2026

## Overview

All ripgrep variants have been renamed to explicitly include the technologies they contain, making it crystal clear what optimizations are in each binary.

## Renaming Map

| Old Name | New Name | What's Inside |
|----------|----------|---------------|
| `rg-standard` | `rg-baseline` | No optimizations (29M) |
| `rg-lto` | `rg-lto` | LTO only (unchanged, 4.1M) |
| `rg-pgo` | `rg-lto-pgo-dynamic` | LTO + PGO + dynamic linking (3.7M) |
| `rg-musl` | `rg-lto-musl` | LTO + static MUSL (5.2M) |
| `rg-pgo-v3` | `rg-lto-pgo-v3-dynamic` | LTO + PGO + AVX2/BMI2/FMA (3.8M) |
| `rg-musl-v3` | `rg-lto-musl-v3` | LTO + static MUSL + AVX2 (5.2M) |
| `rg-bolt` | `rg-lto-pgo-bolt-dynamic` | LTO + PGO + BOLT + dynamic PCRE2 (6.9M) |
| `rg-bolt-pcre2jit` | `rg-lto-pgo-bolt-static-pcre2` | LTO + PGO + BOLT + static PCRE2 JIT (8.9M) |

## Naming Convention

**Format:** `rg-<optimizations>-<architecture>-<linking>`

**Components:**
- **Optimizations**: `lto`, `pgo`, `bolt` (cumulative: bolt implies pgo+lto)
- **Architecture**: (none) = base x86-64, `v3` = x86-64-v3 with AVX2/BMI2/FMA
- **Linking**: `dynamic` = GLIBC dynamic, `musl` = static MUSL, `static-pcre2` = embedded PCRE2

## Technology Breakdown

### LTO (Link-Time Optimization)
- Whole-program optimization at link time
- Enables cross-module inlining and dead code elimination
- Present in ALL optimized variants

### PGO (Profile-Guided Optimization)
- Uses runtime profiling data to optimize hot paths
- +3-4% performance improvement
- Present in: `lto-pgo-*` variants

### BOLT (Binary Optimization and Layout Tool)
- Post-link binary optimizer
- Reorders code layout based on execution profiles
- +1% over PGO alone (dynamic), +8% with static PCRE2
- Present in: `lto-pgo-bolt-*` variants

### x86-64-v3
- CPU microarchitecture level targeting AVX2, BMI2, FMA instructions
- +1% on modern CPUs (2015+)
- Present in: `*-v3-*` variants

### Static PCRE2
- PCRE2 library embedded in binary
- BOLT can optimize across ripgrep/PCRE2 boundary
- +8% on PCRE2 patterns vs dynamic linking
- Present in: `lto-pgo-bolt-static-pcre2`

## Backward Compatibility

**Old symlinks have been removed** - All binaries now use only the new explicit naming scheme.

## Updated Files

### Binaries
- `/proj_soc/user_dev/gczajkowski/bin/rg-*` - All renamed, symlinks created

### Build Scripts
- `tt/build-all-variants.sh` - Updated output names
- `tt/build-pgo.sh` - Updated output names
- `tt/build-musl.sh` - Updated output names
- `tt/build-bolt.sh` - Updated output names
- `tt/build-bolt-pcre2-jit.sh` - Updated output names

### Benchmark Scripts
- `tt/benchmark-quick.sh` - Updated with new names and explicit labels
- `tt/benchmark-local.sh` - Updated with new names
- `tt/benchmark-all-hosts.sh` - Updated with new names
- `tt/benchmark-large-datasets.sh` - NEW: Tests on gigabytes of data

### Documentation
- `tt/README.md` - Updated all references

## Performance Hierarchy

**Standard patterns:**
1. `rg-lto-pgo-bolt-dynamic` - Fastest
2. `rg-lto-pgo-v3-dynamic` - Very close
3. `rg-lto-pgo-dynamic` - Excellent
4. `rg-lto` - Good
5. `rg-baseline` - Baseline

**PCRE2 patterns (with `-P` flag):**
1. `rg-lto-pgo-bolt-static-pcre2` - Fastest (+8% vs dynamic)
2. `rg-lto-pgo-bolt-dynamic` - Excellent
3. `rg-lto-pgo-v3-dynamic` - Very good
4. `rg-lto-pgo-dynamic` - Good

**Portable (no GLIBC dependency):**
1. `rg-lto-musl-v3` - Fastest portable
2. `rg-lto-musl` - Standard portable

## Usage Examples

```bash
# Quick benchmark with new names
./tt/benchmark-quick.sh

# Deep benchmark on large datasets (gigabytes)
./tt/benchmark-large-datasets.sh

# List all variants
ls -lh /proj_soc/user_dev/gczajkowski/bin/rg-lto-*

# Use the ultimate BOLT+static PCRE2 variant
rg-lto-pgo-bolt-static-pcre2 -P '(?i)error:' /large/codebase
```

## Rationale

The old naming was ambiguous:
- `rg-pgo` didn't show it also had LTO
- `rg-bolt` didn't show it had LTO+PGO+BOLT
- Linking type (dynamic vs static) was hidden

The new naming is explicit:
- Every technology is in the name
- Linking type is clear
- Architecture target is obvious
- No confusion about what's included

