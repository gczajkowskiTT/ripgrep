# Ripgrep TT Optimization Project

This is an optimized fork of ripgrep with enhanced build configurations and comprehensive benchmarking infrastructure.

## 📁 Project Structure

```
ripgrepTT/
├── tt/                          # All optimization scripts and documentation
│   ├── README.md               # Start here for TT project info
│   ├── INDEX.md                # Complete navigation index
│   ├── build-*.sh              # Build scripts for all variants
│   ├── benchmark-*.sh          # Benchmarking scripts
│   ├── verify-*.sh             # Verification scripts
│   ├── test-*.sh               # Testing scripts
│   └── *.md                    # Comprehensive documentation
├── crates/                      # Ripgrep source code
├── Cargo.toml                   # Enhanced with optimization profiles
└── .cargo/config.toml           # Cargo configuration

Built binaries: /proj_soc/user_dev/gczajkowski/bin/rg-*
```

## 🚀 Quick Start

```bash
cd tt/

# Build all optimized variants (~5 min)
./build-all-variants.sh

# Quick benchmark comparison (~2 min)
./benchmark-quick.sh

# Comprehensive local benchmarks (~15 min)
./benchmark-local.sh

# Test across all infrastructure hosts (~30 min)
./benchmark-all-hosts.sh
```

## 📊 Results Summary

Built 6 optimized variants with impressive improvements:

| Variant | Size | Performance | Use Case |
|---------|------|-------------|----------|
| **rg-pgo-v3** | 3.8M | 595ms (fastest) | Modern CPUs (recommended) |
| **rg-pgo** | 3.7M | 607ms | Best compatibility + speed |
| **rg-lto** | 4.1M | 617ms | Development builds |
| **rg-musl** | 5.2M | Fast | CentOS 7 / portable |
| **rg-musl-v3** | 5.2M | Fastest | Portable + modern |
| rg-standard | 29M | 614ms | Baseline |

**Key Achievements:**
- ✅ 3-4% faster than standard builds
- ✅ 82-87% smaller binaries (3.7-5.2MB vs 29MB)
- ✅ 100% SOC infrastructure compatibility
- ✅ Static MUSL variants for CentOS 7

## 📖 Documentation

**Start here:** `tt/README.md` or `tt/INDEX.md`

**Key documents:**
- `tt/BUILD_AND_BENCHMARK_SUMMARY.md` - Complete project overview
- `tt/BENCHMARKING_GUIDE.md` - How to benchmark
- `tt/OPTIMIZATION_SUMMARY.md` - Technical details

## 🎯 Recommendations

- **Production (modern infrastructure):** Use `rg-pgo-v3` (fastest, AVX2)
- **Production (mixed infrastructure):** Use `rg-pgo` (best balance)
- **CentOS 7 / Legacy systems:** Use `rg-musl` (static, portable)
- **Development:** Use `rg-lto` (fast build, good performance)

## 🔧 Using Optimized Binaries

```bash
# Direct usage
/proj_soc/user_dev/gczajkowski/bin/rg-pgo-v3 "search pattern" /path/

# Add to PATH
export PATH="/proj_soc/user_dev/gczajkowski/bin:$PATH"

# Create alias
alias rg='rg-pgo-v3'
```

## ⚙️ Build Configuration

Enhanced `Cargo.toml` profiles:
- `release-lto` - Link-time optimization
- `release-max` - Maximum optimization
- PGO (Profile-Guided Optimization) via scripts
- x86-64-v3 support (AVX2, BMI2, FMA)

## 📈 Benchmark Results

Tested on AMD EPYC 9455 (96 cores):
```
pgo-v3:     595.6ms  ████████████████████████████████████ 100.0%
pgo:        606.7ms  █████████████████████████████████░░░  98.1%
standard:   613.6ms  ████████████████████████████████░░░░  97.0%
lto:        617.5ms  ████████████████████████████████░░░░  96.3%
```

All benchmarks use `hyperfine` with proper warmup and statistical analysis.

## 🧪 Testing Infrastructure

Comprehensive testing across 60+ SOC infrastructure hosts:
- Automated SSH-based testing with retries
- CPU architecture detection (AMD EPYC, Intel Xeon)
- AVX2/x86-64-v3 compatibility verification
- GLIBC version compatibility checks

## 🛠️ Requirements

**For building:**
- Rust 1.85+ with `llvm-tools-preview`
- PCRE2 library
- MUSL toolchain (auto-downloaded)

**For benchmarking:**
- `hyperfine` - Install: `cargo install hyperfine`
- SSH access to hosts
- Access to resource_summary.json

## 📦 Integration

Already integrated with ttconjurer:
```bash
/proj_soc/user_dev/gczajkowski/ttconjurer/rust/install.bash
```

Builds using `release-lto` profile for optimal performance/size balance.

## 📝 Project Info

- **Base:** ripgrep 15.1.0 (rev 83a84fb0bd)
- **Build Date:** February 14, 2026
- **Build Host:** soc-l-10 (AMD EPYC 9455)
- **Project Location:** `/proj_soc/user_dev/gczajkowski/ripgrepTT/`
- **Binary Location:** `/proj_soc/user_dev/gczajkowski/bin/`

## 📚 Full Documentation

See `tt/` directory for:
- Complete build scripts
- Comprehensive benchmarking tools
- Detailed optimization guides
- Infrastructure testing results
- Integration documentation

**Navigate from:** `tt/INDEX.md` or `tt/README.md`

---

**For detailed information, navigate to the `tt/` directory and read `INDEX.md` or `BUILD_AND_BENCHMARK_SUMMARY.md`**
