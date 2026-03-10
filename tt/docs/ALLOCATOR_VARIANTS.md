# Memory Allocator Variants - February 14, 2026

## Overview

Added 4 new ripgrep variants testing different memory allocators to understand their impact on performance. Memory allocator choice can significantly affect performance in I/O-heavy workloads like ripgrep.

## Allocator Variants

### jemalloc (2 variants)
**Source:** `/tools_soc/opensrc/jemalloc/5.3.0/`
**Version:** 5.3.0
**Library Size:** 8.8M (dynamic), 46M (static)

#### Characteristics
- **Designed for:** Multi-threaded workloads
- **Key features:**
  - Thread-local caching reduces lock contention
  - Optimized for servers and multi-threaded applications
  - Good at reducing memory fragmentation
  - Used by Firefox, FreeBSD, Facebook

#### Variants
1. **rg-lto-pgo-jemalloc-static** - Statically linked jemalloc
   - Base: LTO + PGO optimization
   - Linking: Static jemalloc (no runtime dependency)

2. **rg-lto-pgo-jemalloc-dynamic** - Dynamically linked jemalloc
   - Base: LTO + PGO optimization
   - Linking: Dynamic jemalloc (requires libjemalloc.so at runtime)

### mimalloc (2 variants)
**Source:** `/tools_soc/opensrc/mimalloc/2.1.7/`
**Version:** 2.1.7
**Library Size:** 174K (dynamic), varies (static)

#### Characteristics
- **Designed for:** Performance and low memory overhead
- **Key features:**
  - Excellent single-threaded performance
  - Very low memory overhead
  - Free-list sharding for thread scalability
  - Developed by Microsoft Research
  - Used by lean, redis, Chez Scheme

#### Variants
1. **rg-lto-pgo-mimalloc-static** - Statically linked mimalloc
   - Base: LTO + PGO optimization
   - Linking: Static mimalloc (no runtime dependency)

2. **rg-lto-pgo-mimalloc-dynamic** - Dynamically linked mimalloc
   - Base: LTO + PGO optimization
   - Linking: Dynamic mimalloc (requires libmimalloc.so at runtime)

## Build Process

Both allocator variants use the same base optimization stack as `rg-lto-pgo-dynamic`:
1. **LTO** (Link-Time Optimization) - Whole-program optimization
2. **PGO** (Profile-Guided Optimization) - Runtime profiling for hot path optimization
3. **Custom allocator** - Replace system allocator (glibc malloc/free)

### Build Commands

```bash
# Build jemalloc variants (both static and dynamic)
./build-jemalloc.sh

# Build mimalloc variants (both static and dynamic)
./build-mimalloc.sh

# Build specific variant only
LINK_MODE=static ./build-jemalloc.sh    # static only
LINK_MODE=dynamic ./build-jemalloc.sh   # dynamic only
```

## Testing Rationale

### Why Test Allocators?

ripgrep's workload characteristics:
1. **I/O heavy** - Reads many files from disk
2. **Memory allocation patterns** - Frequent allocations for:
   - File buffers
   - Match results
   - Regex state
3. **Multi-threaded** - Parallel directory traversal
4. **Short-lived objects** - Most allocations freed quickly

Different allocators may perform better depending on:
- Thread contention (jemalloc advantage)
- Memory overhead (mimalloc advantage)
- Allocation/deallocation speed
- Cache locality
- Memory fragmentation

### Expected Performance Characteristics

**jemalloc:**
- May show improvement on large codebases with many threads
- Better at handling concurrent allocations
- Potentially more consistent performance under load

**mimalloc:**
- May show improvement on single-threaded or lightly-threaded workloads
- Lower memory overhead could improve cache performance
- Potentially faster for small allocations

**System allocator (glibc):**
- Baseline for comparison
- General-purpose, no special optimizations
- Used in `rg-lto-pgo-dynamic` for reference

## Benchmarking

All allocator variants are included in the standard benchmarking suite:

### Quick Benchmark
```bash
./benchmark-quick.sh
# Tests all 15 variants including 4 allocator variants
```

### Comprehensive Benchmark
```bash
./benchmark-local.sh
# 8-test suite on all variants
```

### Functional Verification
```bash
./verify-variants-functional.sh
# Verifies all variants produce correct results
```

## Expected Results

### Performance Expectations

**Scenario 1: Large codebase, many threads**
- jemalloc may show 2-5% improvement over system allocator
- mimalloc may match system allocator

**Scenario 2: Small files, single-threaded**
- mimalloc may show 1-3% improvement over system allocator
- jemalloc may match system allocator

**Scenario 3: Memory-constrained systems**
- mimalloc's lower overhead may provide indirect benefits
- jemalloc's fragmentation handling may help

### Binary Size Impact

Static linking increases binary size:
- jemalloc static: +~40MB (from 3.7M to ~44M)
- mimalloc static: +~1-2MB (from 3.7M to ~5-6M)

Dynamic linking keeps size similar:
- Both allocators: ~3.7-4M (similar to base LTO+PGO)

## Integration with Build System

### Build Scripts
- `build-jemalloc.sh` - Builds both jemalloc variants
- `build-mimalloc.sh` - Builds both mimalloc variants

Both scripts:
- Reuse existing PGO infrastructure (`build-pgo.sh`)
- Support `LINK_MODE` environment variable
- Verify allocator linkage after build
- Install to standard location (`/proj_soc/user_dev/gczajkowski/bin/`)

### Environment Variables
```bash
# For jemalloc builds
RUSTFLAGS="-C target-cpu=native -C link-arg=-L/path/to/jemalloc/lib -C link-arg=-ljemalloc"
JEMALLOC_SYS_WITH_LG_PAGE=16

# For mimalloc builds
RUSTFLAGS="-C target-cpu=native -C link-arg=-L/path/to/mimalloc/lib -C link-arg=-lmimalloc"
```

## Verification

### Checking Allocator Linkage

**Dynamic linking:**
```bash
ldd rg-lto-pgo-jemalloc-dynamic | grep jemalloc
# Should show: libjemalloc.so.2 => /tools_soc/opensrc/jemalloc/5.3.0/lib/libjemalloc.so.2

ldd rg-lto-pgo-mimalloc-dynamic | grep mimalloc
# Should show: libmimalloc.so.2 => /tools_soc/opensrc/mimalloc/2.1.7/lib64/libmimalloc.so.2
```

**Static linking:**
```bash
ldd rg-lto-pgo-jemalloc-static | grep jemalloc
# Should show: nothing (statically linked)

file rg-lto-pgo-jemalloc-static
# Should show: statically linked
```

### Functional Testing
All variants pass the same functional tests as other optimized builds:
```bash
./verify-variants-functional.sh
# Tests allocator variants alongside all others
```

## Recommendations

### When to Use Each Allocator

**Use jemalloc variants when:**
- Searching very large codebases (hundreds of GB)
- Running on machines with many CPU cores (>16)
- Dealing with concurrent workloads
- Memory fragmentation is a concern

**Use mimalloc variants when:**
- Memory overhead is critical
- Running on memory-constrained systems
- Single-threaded or lightly-threaded workloads
- Want smallest static binary size

**Use standard variants (system allocator) when:**
- Default choice for most use cases
- No specific allocator requirements
- Simplicity and portability preferred
- Binary size is critical (dynamic linking)

## Technical Details

### Linking Flags

**jemalloc static:**
```
-C link-arg=-L/tools_soc/opensrc/jemalloc/5.3.0/lib
-C link-arg=-ljemalloc
```

**jemalloc dynamic:**
```
-C link-arg=-L/tools_soc/opensrc/jemalloc/5.3.0/lib
-C link-arg=-ljemalloc
-C link-arg=-Wl,-rpath,/tools_soc/opensrc/jemalloc/5.3.0/lib
```

**mimalloc static:**
```
-C link-arg=-L/tools_soc/opensrc/mimalloc/2.1.7/lib64/mimalloc-2.1
-C link-arg=-lmimalloc
-C link-arg=-lpthread
```

**mimalloc dynamic:**
```
-C link-arg=-L/tools_soc/opensrc/mimalloc/2.1.7/lib64
-C link-arg=-lmimalloc
-C link-arg=-Wl,-rpath,/tools_soc/opensrc/mimalloc/2.1.7/lib64
```

## Future Work

Potential additional testing:
1. Compare with tcmalloc (Google's allocator)
2. Test on CentOS 7 with older glibc
3. Memory profiling with valgrind/massif
4. Long-running stability tests
5. Memory fragmentation analysis

## References

- jemalloc: http://jemalloc.net/
- mimalloc: https://github.com/microsoft/mimalloc
- Allocator comparison: https://github.com/daanx/mimalloc-bench

## Summary

Added 4 allocator variants to test memory allocator impact on ripgrep performance:
- 2 jemalloc variants (static + dynamic)
- 2 mimalloc variants (static + dynamic)

All variants built on LTO+PGO base for fair comparison. Testing will reveal if allocator choice provides measurable benefit for ripgrep's workload.
