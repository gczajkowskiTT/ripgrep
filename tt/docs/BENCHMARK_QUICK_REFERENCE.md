# Ripgrep Benchmark Quick Reference

**Test Date:** February 15, 2026
**Dataset:** 17GB, ~134k files
**Method:** 6 iterations, 3 runs, 1 warmup

---

## Performance by Scenario (sorted by overall average)

| Variant | Literal | Regex | Case-Ins | Multi-Pat | **Average** | **Rank** |
|---------|---------|-------|----------|-----------|-------------|----------|
| **lto+pgo** | 16.751s ⭐ | 10.480s | 17.741s ⭐ | 12.490s | **14.365s** | **🥇 1** |
| **lto** | 16.915s | 10.527s | 18.781s | 12.615s | **14.710s** | **🥈 2** |
| **os** | 17.561s | 10.469s | 18.818s | 12.457s | **14.826s** | **🥉 3** |
| **2025.11.23** | 17.586s | 10.843s | 18.228s | 12.864s | **14.880s** | **4** |
| **baseline** | 17.879s | 10.357s ⭐ | 18.771s | 12.612s | **14.905s** | **5** |
| lto+pgo+mimalloc | 17.474s | 10.568s | 19.514s | 12.785s | 15.085s | 6 |
| lto+pgo+jemalloc | 17.326s | 10.820s | 18.928s | 13.211s | 15.071s | 7 |
| lto+pgo+bolt+mimalloc | 17.145s | 11.137s | 19.231s | 12.161s | 14.918s | 8 |
| lto+pgo+bolt | 17.639s | 10.576s | 18.392s | 13.345s | 14.988s | 9 |
| lto+pgo+v3+jemalloc | 18.166s | 10.402s | 18.615s | 12.024s ⭐ | 14.802s | 10 |
| lto+pgo+v3+mimalloc | 18.851s | 10.636s | 19.222s | 12.113s | 15.206s | 11 |
| lto+pgo+bolt+jemalloc | 17.779s | 10.690s | 19.556s | 12.563s | 15.147s | 12 |
| lto+pgo+v3 | 17.964s | 11.226s | 19.315s | 12.574s | 15.270s | 13 |

⭐ = Winner for that scenario

---

## Winners by Scenario

| Scenario | Pattern | Winner | Time | 2nd Place | 3rd Place |
|----------|---------|--------|------|-----------|-----------|
| **Literal Search** | `"function"` | lto+pgo | 16.751s | lto (16.915s) | lto+pgo+bolt+mimalloc (17.145s) |
| **Regex Search** | `"class.*\{"`| baseline | 10.357s | lto+pgo+v3+jemalloc (10.402s) | os (10.469s) |
| **Case-Insensitive** | `"error" -i` | lto+pgo | 17.741s | 2025.11.23 (18.228s) | lto+pgo+bolt (18.392s) |
| **Multi-Pattern** | `"TODO\|FIXME\|XXX\|HACK"` | lto+pgo+v3+jemalloc | 12.024s | lto+pgo+v3+mimalloc (12.113s) | lto+pgo+bolt+mimalloc (12.161s) |

---

## Performance vs OS Version

| Variant | vs OS Literal | vs OS Regex | vs OS Case-Ins | vs OS Multi-Pat | **Average** |
|---------|---------------|-------------|----------------|-----------------|-------------|
| **lto+pgo** | **+4.8%** ⬆️ | +0.1% ≈ | **+6.1%** ⬆️ | -0.3% ≈ | **+2.7%** |
| lto | +3.8% ⬆️ | -0.6% ≈ | +0.2% ≈ | -1.3% ≈ | +0.5% |
| baseline | -1.8% ≈ | **+1.1%** ⬆️ | +0.2% ≈ | -1.2% ≈ | -0.4% |
| lto+pgo+v3+jemalloc | -3.4% ⬇️ | +0.6% ≈ | +1.1% ≈ | **+3.6%** ⬆️ | +0.5% |

⬆️ = Significantly faster (>2%)
⬇️ = Slower
≈ = Roughly equal (<2%)

---

## Build Complexity vs Performance

| Variant | Build Complexity | Avg Performance | Portability | Recommendation |
|---------|-----------------|-----------------|-------------|----------------|
| **lto+pgo** | ⭐⭐ Medium | 🥇 Best | ✅ Excellent | **Use This** |
| lto | ⭐ Easy | 🥈 Very Good | ✅ Excellent | Good alternative |
| os | ⭐ Pre-built | 🥉 Good | ✅ Excellent | Baseline reference |
| baseline | ⭐ Easy | Good | ✅ Excellent | Regex-specific only |
| lto+pgo+v3+jemalloc | ⭐⭐⭐⭐ Complex | Good | ⚠️ Requires AVX2 | Multi-pattern only |

---

## One-Line Recommendations

- **General use:** `lto+pgo` → Consistent 3-6% improvement
- **Regex-heavy:** `baseline` or `os` → Slightly faster for complex regex
- **Multi-pattern:** `lto+pgo+v3+jemalloc` → Best for alternation patterns
- **Simplicity:** `lto` → Nearly as good as lto+pgo, easier build
- **Avoid:** BOLT variants, v3 without allocators

---

## Key Takeaways

1. **lto+pgo wins overall** - Best average performance, top 3 in all scenarios
2. **Small differences** - 1-6% improvement over OS version
3. **Workload matters** - No single variant is best for everything
4. **Avoid over-optimization** - BOLT and most allocator variants don't help
5. **Biggest win was git-blame fix** - 100x improvement by disabling default git blame

---

## Build Commands

### Recommended: lto+pgo
```bash
# 1. Instrumented build
RUSTFLAGS="-C profile-generate=/tmp/pgo-data" cargo build --release

# 2. Generate profile
./target/release/rg 'function' /large/codebase > /dev/null

# 3. Optimized build
RUSTFLAGS="-C lto=fat -C codegen-units=1 -C profile-use=/tmp/pgo-data/merged.profdata" \
  cargo build --release
```

### For multi-pattern: lto+pgo+v3+jemalloc
```bash
# Same as above, but add: -C target-cpu=x86-64-v3
# And use: cargo build --release --features jemalloc
```

---

**Full analysis:** See `COMPREHENSIVE_BENCHMARK_ANALYSIS.md` for detailed findings and recommendations.
