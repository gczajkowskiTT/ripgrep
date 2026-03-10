# Ripgrep Linker Benchmark Report

## Objective

Compare different linkers to determine their impact on:
1. **Build Time** - How long linking takes
2. **Binary Size** - Size of the final executable
3. **Runtime Performance** - Speed of the resulting binary

## Tested Linkers

| Linker | Version | Path | Notes |
|--------|---------|------|-------|
| default | system ld | (gcc default) | Baseline |
| lld | 21.0.0 | /tools_soc/opensrc/clang/21.0.0/bin/lld | LLVM linker |
| mold | 2.36.0 | /tools_soc/opensrc/mold/2.36.0/bin/mold | Fast linker |
| mold | 2.40.2 | /tools_soc/opensrc/mold/2.40.2/bin/mold | Newer version |
| mold | 2.40.4-default | /tools_soc/opensrc/mold/2.40.4/default/bin/mold | Latest default |
| mold | 2.40.4-thinlto-pgo | /tools_soc/opensrc/mold/2.40.4/thinlto-pgo/bin/mold | ThinLTO+PGO optimized mold |
| mold | 2.40.4-fulllto-pgo-bolt | /tools_soc/opensrc/mold/2.40.4/fulllto-pgo-bolt/bin/mold | Fully optimized mold |
| mold | stable | /tools_soc/opensrc/mold/stable/bin/mold | Symlink to stable version |

## Test Variants

Three representative variants tested:
1. **lto-thin** - Simple LTO optimization (recommended baseline)
2. **lto-pgo-mimalloc-pcre2-dynamic** - PGO + allocator
3. **lto-pgo-bolt-v3-mimalloc-pcre2-dynamic** - Full optimization stack

## Build Results


### Build Time Comparison

| Linker | Variant | Build Time (s) | Binary Size | Status |
|--------|---------|----------------|-------------|--------|
| mold-2.36.0 | lto-thin | 26 | 4.17M | SUCCESS |
| mold-2.40.4-default | lto-thin | 25 | 4.17M | SUCCESS |
| mold-2.40.4-thinlto-pgo | lto-thin | 25 | 4.17M | SUCCESS |
| mold-stable | lto-thin | 25 | 4.17M | SUCCESS |
| mold-2.40.2 | lto-thin | 25 | 4.17M | SUCCESS |
| lld | lto-thin | 25 | 4.17M | SUCCESS |
| mold-2.40.4-fulllto-pgo-bolt | lto-thin | 25 | 4.17M | SUCCESS |
| default | lto-thin | 25 | 4.17M | SUCCESS |
| mold-2.36.0 | lto-pgo-mimalloc-pcre2-dynamic | 84 | 3.93M | SUCCESS |
| mold-2.40.4-default | lto-pgo-mimalloc-pcre2-dynamic | 85 | 3.93M | SUCCESS |
| mold-2.40.4-thinlto-pgo | lto-pgo-mimalloc-pcre2-dynamic | 84 | 3.93M | SUCCESS |
| mold-stable | lto-pgo-mimalloc-pcre2-dynamic | 84 | 3.93M | SUCCESS |
| mold-2.40.2 | lto-pgo-mimalloc-pcre2-dynamic | 84 | 3.93M | SUCCESS |
| lld | lto-pgo-mimalloc-pcre2-dynamic | 83 | 3.93M | SUCCESS |
| mold-2.40.4-fulllto-pgo-bolt | lto-pgo-mimalloc-pcre2-dynamic | 83 | 3.93M | SUCCESS |
| default | lto-pgo-mimalloc-pcre2-dynamic | 84 | 3.93M | SUCCESS |
| mold-2.36.0 | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 104 | 6.29M | SUCCESS |
| mold-2.40.4-default | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 105 | 6.29M | SUCCESS |
| mold-2.40.4-thinlto-pgo | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 103 | 6.29M | SUCCESS |
| mold-stable | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 104 | 6.29M | SUCCESS |
| mold-2.40.2 | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 103 | 6.29M | SUCCESS |
| lld | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 104 | 6.29M | SUCCESS |
| mold-2.40.4-fulllto-pgo-bolt | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 105 | 6.29M | SUCCESS |
| default | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 102 | 6.29M | SUCCESS |

### Runtime Performance

| Linker | Variant | Mean Time (s) | Std Dev (s) |
|--------|---------|---------------|-------------|
| mold-2.36.0 | lto-thin | 5.923 | 0.178 |
| mold-2.40.4-default | lto-thin | 5.923 | 0.167 |
| mold-2.40.4-thinlto-pgo | lto-thin | 5.876 | 0.214 |
| mold-stable | lto-thin | 5.837 | 0.066 |
| mold-2.40.2 | lto-thin | 5.905 | 0.127 |
| lld | lto-thin | 5.890 | 0.171 |
| mold-2.40.4-fulllto-pgo-bolt | lto-thin | 5.901 | 0.126 |
| default | lto-thin | 5.930 | 0.105 |
| mold-2.36.0 | lto-pgo-mimalloc-pcre2-dynamic | 5.921 | 0.104 |
| mold-2.40.4-default | lto-pgo-mimalloc-pcre2-dynamic | 5.907 | 0.167 |
| mold-2.40.4-thinlto-pgo | lto-pgo-mimalloc-pcre2-dynamic | 5.856 | 0.091 |
| mold-stable | lto-pgo-mimalloc-pcre2-dynamic | 5.822 | 0.083 |
| mold-2.40.2 | lto-pgo-mimalloc-pcre2-dynamic | 5.846 | 0.226 |
| lld | lto-pgo-mimalloc-pcre2-dynamic | 5.853 | 0.181 |
| mold-2.40.4-fulllto-pgo-bolt | lto-pgo-mimalloc-pcre2-dynamic | 5.862 | 0.080 |
| default | lto-pgo-mimalloc-pcre2-dynamic | 5.520 | 0.228 |
| mold-2.36.0 | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 4.942 | 0.103 |
| mold-2.40.4-default | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 4.174 | 0.187 |
| mold-2.40.4-thinlto-pgo | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 3.603 | 0.101 |
| mold-stable | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 3.296 | 0.080 |
| mold-2.40.2 | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 3.196 | 0.141 |
| lld | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 3.278 | 0.076 |
| mold-2.40.4-fulllto-pgo-bolt | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 3.259 | 0.050 |
| default | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 3.141 | 0.081 |

### Memory Usage

| Linker | Variant | Max RSS (MB) | Avg RSS (MB) | Page Faults | Context Switches |
|--------|---------|--------------|--------------|-------------|------------------|
| mold-2.36.0 | lto-thin | 16.76 | 16.07 | 0 | 0 |
| mold-2.40.4-default | lto-thin | 16.07 | 15.58 | 0 | 0 |
| mold-2.40.4-thinlto-pgo | lto-thin | 15.62 | 14.91 | 0 | 0 |
| mold-stable | lto-thin | 16.21 | 15.38 | 0 | 0 |
| mold-2.40.2 | lto-thin | 16.85 | 15.24 | 0 | 0 |
| lld | lto-thin | 16.52 | 16.31 | 0 | 0 |
| mold-2.40.4-fulllto-pgo-bolt | lto-thin | 17.09 | 15.81 | 0 | 0 |
| default | lto-thin | 16.82 | 16.23 | 0 | 0 |
| mold-2.36.0 | lto-pgo-mimalloc-pcre2-dynamic | 21.48 | 21.00 | 0 | 0 |
| mold-2.40.4-default | lto-pgo-mimalloc-pcre2-dynamic | 20.73 | 20.31 | 0 | 0 |
| mold-2.40.4-thinlto-pgo | lto-pgo-mimalloc-pcre2-dynamic | 20.97 | 20.50 | 0 | 0 |
| mold-stable | lto-pgo-mimalloc-pcre2-dynamic | 22.05 | 21.64 | 0 | 0 |
| mold-2.40.2 | lto-pgo-mimalloc-pcre2-dynamic | 23.19 | 21.37 | 0 | 0 |
| lld | lto-pgo-mimalloc-pcre2-dynamic | 21.63 | 20.99 | 0 | 0 |
| mold-2.40.4-fulllto-pgo-bolt | lto-pgo-mimalloc-pcre2-dynamic | 21.79 | 21.15 | 0 | 0 |
| default | lto-pgo-mimalloc-pcre2-dynamic | 19.95 | 19.53 | 0 | 0 |
| mold-2.36.0 | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 20.86 | 20.69 | 0 | 0 |
| mold-2.40.4-default | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 22.93 | 21.59 | 0 | 0 |
| mold-2.40.4-thinlto-pgo | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 22.73 | 21.68 | 0 | 0 |
| mold-stable | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 22.50 | 21.58 | 0 | 0 |
| mold-2.40.2 | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 20.92 | 20.26 | 0 | 0 |
| lld | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 22.07 | 21.14 | 0 | 0 |
| mold-2.40.4-fulllto-pgo-bolt | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 22.86 | 21.97 | 0 | 0 |
| default | lto-pgo-bolt-v3-mimalloc-pcre2-dynamic | 22.70 | 21.67 | 0 | 0 |

## Analysis

### Build Time Analysis

The linker has a direct impact on build time since it's the final phase of compilation:
- **Fastest Linker**: Check build results table above
- **Slowest Linker**: Check build results table above
- **Impact**: Difference between fastest and slowest linker

### Binary Size Impact

Some linkers may produce slightly different binary sizes due to:
- Different section alignment
- Debug information handling
- Symbol table organization

### Runtime Performance Impact

The linker should NOT significantly impact runtime performance for release builds since:
- Code generation happens before linking
- Optimizations are done by LLVM/Rust compiler
- Linker only arranges sections and resolves symbols

However, section layout can affect:
- CPU cache utilization
- Page faults
- Memory locality

### Memory Usage Analysis

Memory usage during execution is measured by:
- **Max RSS**: Maximum resident set size (peak memory usage)
- **Avg RSS**: Average resident set size across runs
- **Page Faults**: Major page faults requiring I/O
- **Context Switches**: Voluntary context switches

## Recommendations

Based on the complete results:

### For Development Builds
- **Fastest Link Time**: Choose the linker with shortest build time
- **Recommendation**: mold is typically 2-5x faster than ld

### For Production Builds
- **Best Performance**: Choose linker with best runtime + memory profile
- **Best Size**: Choose linker producing smallest binary
- **Balanced**: Consider build time vs runtime performance tradeoff

### Specific Recommendations
- **Fastest Build**: TBD (check Build Time Comparison table)
- **Smallest Binary**: TBD (check Binary Size column)
- **Best Runtime**: TBD (check Runtime Performance table)
- **Lowest Memory**: TBD (check Memory Usage table)
- **Overall Recommended**: TBD (balanced choice)

## Conclusion

### Build Environment
- Scratch directory: /localdev/$USER
- Cargo target: /localdev/$USER/cargo-linker-benchmark
- Temp directory: /localdev/$USER/TMPDIR

### Key Findings
1. **Build Speed**: [Analysis of linker build speed differences]
2. **Binary Size**: [Analysis of binary size variations]
3. **Runtime Impact**: [Analysis of runtime performance differences]
4. **Memory Impact**: [Analysis of memory usage patterns]

### Final Recommendation
[Select the best overall linker based on the specific use case and priorities]

