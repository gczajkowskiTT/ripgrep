# BOLT-Optimized Ripgrep Variant

**Status:** Advanced optimization - build separately
**Expected Performance Gain:** 5-10% over PGO baseline
**Build Time:** ~15-20 minutes (includes profiling)

## Overview

BOLT (Binary Optimization and Layout Tool) is a post-link optimizer that reorders code layout based on actual execution profiles to improve:
- **Instruction cache utilization** through hot/cold code separation
- **Branch prediction** via optimized code layout
- **Overall performance** through better cache locality

BOLT optimization is applied **after** PGO optimization, providing additional performance gains.

## Requirements

### System Requirements
- Linux with `perf` support
- Clang module with BOLT support (loaded via `module load clang`)
- Rust with `llvm-tools-preview`
- PGO-optimized binary (built automatically if not present)

### Tool Verification

```bash
# Check if module system is available
module --version

# Load clang module (contains BOLT)
module load clang

# Verify BOLT tools are available
which llvm-bolt
which perf2bolt

# Verify other required tools
which perf
which llvm-profdata
```

## Building BOLT Variant

### Quick Build

```bash
cd /proj_soc/user_dev/gczajkowski/ripgrepTT/tt

# Build with default settings
./build-bolt.sh
```

This will:
1. Build PGO-optimized binary (if not already built)
2. Collect execution profile with `perf` (5 runs by default)
3. Convert profile to BOLT format
4. Optimize binary with BOLT
5. Install as `rg-bolt` in `/proj_soc/user_dev/gczajkowski/bin/`

### Advanced Build Options

```bash
# Use custom workload directory for profiling
./build-bolt.sh --workload-dir /large/codebase

# Collect more profile runs for better optimization
./build-bolt.sh --profile-runs 10

# Clean build from scratch
./build-bolt.sh --clean

# Skip PGO build (use existing binary)
./build-bolt.sh --skip-pgo

# Skip profile collection (use existing perf.data)
./build-bolt.sh --skip-profile

# Custom features
./build-bolt.sh --features "pcre2"
```

### Help

```bash
./build-bolt.sh --help
```

## Build Process Explained

### Step 1: PGO Build
First, a PGO-optimized binary is built as the base. BOLT works on top of PGO optimization.

```bash
# Automatically calls build-pgo.sh or builds PGO manually
target/release-lto/rg  (PGO-optimized)
```

### Step 2: Profile Collection
The PGO binary is run multiple times with `perf` to collect execution profiles.

```bash
# Default: 5 profiling runs with different patterns
perf record -e cycles:u -j any,u --append -o perf.data -- rg "fn " crates/
perf record -e cycles:u -j any,u --append -o perf.data -- rg "struct " crates/
# ... more runs
```

### Step 3: BOLT Format Conversion
Profile data is converted from `perf` format to BOLT format.

```bash
perf2bolt -p perf.data -o perf.fdata target/release-lto/rg
```

### Step 4: BOLT Optimization
The binary is optimized using BOLT with the profile data.

```bash
llvm-bolt target/release-lto/rg \
  -o target/release-lto/rg-bolt \
  -data=perf.fdata \
  -reorder-blocks=ext-tsp \
  -reorder-functions=hfsort+ \
  -split-functions=3 \
  -split-all-cold \
  -split-eh \
  -dyno-stats \
  -icf=1 \
  -use-gnu-stack
```

## BOLT Optimization Flags Explained

- **`-reorder-blocks=ext-tsp`** - Reorder basic blocks using extended TSP algorithm
- **`-reorder-functions=hfsort+`** - Reorder functions by hotness
- **`-split-functions=3`** - Split functions into hot and cold parts (aggressiveness level 3)
- **`-split-all-cold`** - Move all cold code to separate section
- **`-split-eh`** - Split exception handling code
- **`-dyno-stats`** - Print dynamic execution statistics
- **`-icf=1`** - Perform identical code folding
- **`-use-gnu-stack`** - Use GNU stack for compatibility

## Performance Testing

### Quick Test

After building, the script automatically runs a quick performance comparison:

```bash
hyperfine --warmup 3 --runs 5 \
  --command-name "pgo" "rg-pgo 'fn ' crates/" \
  --command-name "bolt" "rg-bolt 'fn ' crates/"
```

### Comprehensive Benchmark

```bash
cd /proj_soc/user_dev/gczajkowski/ripgrepTT/tt

# Compare all variants including BOLT
hyperfine --warmup 3 --runs 10 \
  --command-name "standard" "/proj_soc/user_dev/gczajkowski/bin/rg-standard 'fn ' ../crates/" \
  --command-name "lto" "/proj_soc/user_dev/gczajkowski/bin/rg-lto 'fn ' ../crates/" \
  --command-name "pgo" "/proj_soc/user_dev/gczajkowski/bin/rg-pgo 'fn ' ../crates/" \
  --command-name "pgo-v3" "/proj_soc/user_dev/gczajkowski/bin/rg-pgo-v3 'fn ' ../crates/" \
  --command-name "bolt" "/proj_soc/user_dev/gczajkowski/bin/rg-bolt 'fn ' ../crates/"
```

## Expected Results

Based on BOLT's typical performance gains:

### Performance
- **5-10% faster** than PGO baseline
- **8-15% faster** than standard builds
- Best results on large codebases with complex control flow

### Binary Size
- Slightly larger than PGO (~100-200KB)
- Still much smaller than standard build (3.8-4.0MB vs 29MB)

### When BOLT Works Best
- ✅ Large codebases (>10,000 files)
- ✅ Complex control flow with many branches
- ✅ Cache-sensitive workloads
- ✅ Repeated searches on same codebase

### When BOLT May Not Help Much
- ❌ Very small searches (startup overhead dominates)
- ❌ Simple linear scans
- ❌ I/O-bound workloads

## Installed Binary

```bash
Location: /proj_soc/user_dev/gczajkowski/bin/rg-bolt
Size: ~3.8-4.0MB
Type: Dynamically linked (GLIBC 2.28+)
Features: PCRE2, AVX2 runtime detection
```

## Usage

```bash
# Direct usage
/proj_soc/user_dev/gczajkowski/bin/rg-bolt "pattern" /path/to/search

# Add to PATH
export PATH="/proj_soc/user_dev/gczajkowski/bin:$PATH"

# Use as default rg
alias rg='rg-bolt'
```

## Verification

After building, verify the binary works:

```bash
# Check version
/proj_soc/user_dev/gczajkowski/bin/rg-bolt --version

# Test search
/proj_soc/user_dev/gczajkowski/bin/rg-bolt "fn " ../crates/ | wc -l

# Should return: 2763 matches
```

## Troubleshooting

### Error: llvm-bolt not found

```bash
# Load clang module
module load clang

# Verify BOLT is available
which llvm-bolt
```

### Error: perf not found

```bash
# Install perf
sudo yum install perf

# Or on Ubuntu/Debian
sudo apt-get install linux-tools-common linux-tools-generic
```

### Error: Module command not found

If you don't have the module system:
- Install LLVM with BOLT manually
- Or use a system with the module environment

### Profile collection fails

```bash
# Check perf permissions
sudo sysctl -w kernel.perf_event_paranoid=-1

# Or run as root (not recommended)
sudo ./build-bolt.sh
```

### BOLT optimization fails

Check `bolt-optimization.log` for details:
```bash
cat bolt-optimization.log
```

Common issues:
- Binary stripped (BOLT needs symbols)
- Insufficient profile data (increase --profile-runs)
- Binary format not supported

## Build Artifacts

After building, you'll find:

```
ripgrepTT/
├── target/release-lto/
│   ├── rg              # PGO-optimized (input)
│   └── rg-bolt         # BOLT-optimized (output)
├── perf.data           # Raw perf profile data
├── perf.fdata          # BOLT-format profile
└── bolt-optimization.log  # BOLT output
```

## Combining with Other Optimizations

BOLT can be combined with:

### ✅ Compatible
- **PGO** - BOLT builds on top of PGO (required)
- **LTO** - Already in PGO build
- **x86-64-v3** - Can apply to v3 variant
- **Custom allocators** - Can use after BOLT

### Building BOLT + x86-64-v3

```bash
# First build PGO-v3 variant
cd /proj_soc/user_dev/gczajkowski/ripgrepTT/tt
./build-all-variants.sh  # Builds rg-pgo-v3

# Then apply BOLT to the v3 variant
# (Manual process - copy pgo-v3 binary first)
cp /proj_soc/user_dev/gczajkowski/bin/rg-pgo-v3 target/release-lto/rg
./build-bolt.sh --skip-pgo
mv /proj_soc/user_dev/gczajkowski/bin/rg-bolt /proj_soc/user_dev/gczajkowski/bin/rg-bolt-v3
```

## Integration with Benchmarking

To include BOLT in benchmark suite:

```bash
cd tt/

# Edit benchmark-local.sh or benchmark-quick.sh
# Add rg-bolt to the list of variants to test
```

## Variant Summary

After building BOLT variant, you'll have:

| Variant | Size | Optimization | Speed | Use Case |
|---------|------|--------------|-------|----------|
| rg-standard | 29M | None | Baseline | Reference |
| rg-lto | 4.1M | LTO | +2-3% | Development |
| rg-pgo | 3.7M | PGO + LTO | +3-4% | Production |
| rg-pgo-v3 | 3.8M | PGO + LTO + AVX2 | +4-5% | Modern CPUs |
| **rg-bolt** | **3.9M** | **PGO + LTO + BOLT** | **+8-14%** | **Maximum performance** |

## References

- [BOLT GitHub](https://github.com/llvm/llvm-project/tree/main/bolt)
- [BOLT Paper](https://research.facebook.com/publications/bolt-a-practical-binary-optimizer-for-data-centers-and-beyond/)
- [LLVM BOLT Documentation](https://llvm.org/docs/CommandGuide/llvm-bolt.html)

## Support

For issues or questions:
1. Check `bolt-optimization.log` for BOLT errors
2. Verify clang module is loaded: `module list | grep clang`
3. Test with smaller profile runs: `./build-bolt.sh --profile-runs 3`
4. Review FUTURE_OPTIMIZATIONS.md for detailed BOLT information

---

**Last Updated:** February 14, 2026
**Script Location:** `/proj_soc/user_dev/gczajkowski/ripgrepTT/tt/build-bolt.sh`
**Binary Location:** `/proj_soc/user_dev/gczajkowski/bin/rg-bolt`
