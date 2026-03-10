# Ripgrep Benchmarking Suite

Comprehensive benchmarking system for testing optimized ripgrep variants.

## Scripts Overview

### 1. verify-binaries.sh
**Purpose:** Comprehensive verification of all binaries
**Duration:** ~1-2 minutes
**Usage:**
```bash
./verify-binaries.sh --bindir /proj_soc/user_dev/gczajkowski/bin
```

**What it tests (8 comprehensive tests):**
1. Version check
2. Literal search
3. Regex pattern
4. Case-insensitive search
5. Multi-pattern search
6. Count mode
7. Type filtering
8. PCRE2 pattern

**Features:**
- Dynamically discovers all rg-* binaries
- Reports version, size, and linking (static/dynamic) for each binary
- No hardcoded binary names or paths

**Output:** Pass/Fail status for each binary with detailed test results

---

### 2. benchmark-quick.sh
**Purpose:** Fast performance overview
**Duration:** ~15 minutes (~1 minute per variant)
**Dataset:** chiplet-template (17GB, ~134k files)
**Iterations:** 2 per scenario
**Usage:**
```bash
./benchmark-quick.sh
# Or with custom dataset:
DATASET=/path/to/code ./benchmark-quick.sh
```

**Scenarios tested:**
1. Literal search: `"function"`
2. Regex search: `"class.*\{"`
3. Case-insensitive: `"error"` with `-i`
4. Multi-pattern: `"TODO|FIXME|XXX|HACK"`

**Results:** benchmark-results-quick/

---

### 3. benchmark-medium.sh
**Purpose:** Medium-length comprehensive benchmark
**Duration:** ~30 minutes (~2.3 minutes per variant)
**Dataset:** chiplet-template (17GB, ~134k files)
**Iterations:** 6 per scenario
**Usage:**
```bash
./benchmark-medium.sh
```

**Use when:** You need statistically significant results with good confidence intervals

**Results:** benchmark-results-medium/

---

### 4. benchmark-long.sh
**Purpose:** Long-running stress test with massive dataset
**Duration:** ~60 minutes (~4.6 minutes per variant)
**Dataset:** /proj_soc_scratch_ps/.../tensix/soc/ (very large)
**Iterations:** 3 per scenario
**Usage:**
```bash
./benchmark-long.sh
# Or with custom dataset:
DATASET=/proj_soc_scratch_ps/other ./benchmark-long.sh
```

**Use when:** Testing performance on large-scale data

**Results:** benchmark-results-long/

---

### 5. benchmark-claude.sh
**Purpose:** Claude-specific workload simulation
**Duration:** ~40 minutes
**Dataset:** chiplet-template (17GB, ~134k files)
**Iterations:** 10 per scenario (simulates many quick searches)
**Hyperfine runs:** 5 (more runs for stable results)
**Usage:**
```bash
./benchmark-claude.sh
```

**What makes it Claude-specific:**
- **Many quick searches:** 10 iterations simulate Claude's typical usage pattern
- **Binary size matters:** Results include size (important for distribution)
- **Real codebase:** Tests on actual source code structure
- **Multiple runs:** 5 hyperfine runs for confidence

**Results:** benchmark-results-claude/

---

### 6. benchmark-generic.sh
**Purpose:** Flexible generic benchmark script (used by all wrappers)
**Usage:**
```bash
./benchmark-generic.sh \
    --bindir /path/to/binaries \
    --results-dir /path/to/results \
    --dataset /path/to/dataset \
    --name "My Benchmark" \
    [--iterations N] \
    [--runs N] \
    [--reference /path/to/rg] \
    [--reference-name "Name"] \
    [--timeout SECONDS]
```

**Required Parameters:**
- `--bindir`: Directory containing rg-* binaries
- `--results-dir`: Where to save results
- `--dataset`: Dataset to search

**Optional Parameters:**
- `--name`: Benchmark name (default: "Default Benchmark")
- `--iterations`: Iterations per scenario (default: 3)
- `--runs`: Hyperfine runs (default: 3)
- `--reference`: Reference binary (default: /usr/bin/rg)
- `--reference-name`: Reference name (default: "OS installed RipGrep")
- `--timeout`: Timeout in seconds (default: 43200 = 12 hours)

**What it does:**
1. Discovers all rg-* binaries in --bindir
2. Extracts version numbers from each binary
3. Tests if binaries support --no-git-blame
4. Runs 4 scenarios: literal, regex, case-insensitive, multi-pattern
5. Exports results in JSON, Markdown, and AsciiDoc formats
6. Reports binary sizes and versions
7. Times the entire benchmark

---

## Environment Variables

All scripts support these environment variables:

- `BIN_DIR`: Override binary directory (default: /proj_soc/user_dev/gczajkowski/bin)
- `DATASET`: Override test dataset

**Example:**
```bash
BIN_DIR=/custom/path DATASET=/large/codebase ./benchmark-quick.sh
```

---

## Output Formats

Each benchmark produces 3 output formats per scenario:

1. **JSON** (`*_scenario.json`)
   - Machine-readable
   - Full hyperfine statistics
   - For automated analysis

2. **Markdown** (`*_scenario.md`)
   - Human-readable tables
   - GitHub/GitLab compatible
   - Quick visual comparison

3. **AsciiDoc** (`*_scenario.adoc`)
   - Documentation format
   - Can be converted to PDF/HTML
   - Publication-ready

---

## Benchmarking Workflow

### Quick Performance Check
```bash
# 1. Verify all binaries work
./verify-binaries.sh

# 2. Quick benchmark (15 min)
./benchmark-quick.sh

# 3. Analyze results
cat benchmark-results-quick/*.md
```

### Comprehensive Benchmarking
```bash
# 1. Verify binaries
./verify-binaries.sh

# 2. Run medium benchmark
./benchmark-medium.sh

# 3. Analyze results
cat benchmark-results-medium/*.md
```

### Claude-Specific Testing
```bash
# Test specifically for Claude's workload
./benchmark-claude.sh

# Results show binary sizes and many-search performance
cat benchmark-results-claude/*.md
```

### Custom Benchmark
```bash
# Custom dataset, custom iterations
./benchmark-generic.sh \
    --bindir ~/bin \
    --results-dir ./custom-results \
    --dataset /my/large/codebase \
    --name "Custom Test" \
    --iterations 5 \
    --runs 10 \
    --timeout 7200
```

---

## Binary Size Comparison

All benchmarks include binary sizes in results. This is important because:

- **Smaller binaries** = faster loading, less memory, better for distribution
- **Larger binaries** may have more optimizations but cost more resources
- **Claude's use case:** Binary size matters for tool distribution

Example output:
```
os [v14.1.1, 6.3M]: 10.234s ± 0.123s
lto+pgo [v15.1.0, 3.8M]: 9.876s ± 0.098s  ← Smaller AND faster!
lto+pgo+bolt [v15.1.0, 33M]: 9.912s ± 0.156s  ← Much larger, barely faster
```

---

## Performance Analysis Tips

### Comparing Variants

1. **Look at mean time:** Lower is better
2. **Check std dev:** Lower = more consistent
3. **Consider binary size:** Smaller is better if performance is similar
4. **Use relative column:** Shows speedup vs reference

### Statistical Significance

- **Quick benchmark (2 iter, 3 runs):** Good for rough comparison
- **30-min benchmark (6 iter, 3 runs):** Good confidence intervals
- **60-min benchmark (3 iter, 3 runs):** Stress test, larger dataset
- **Claude benchmark (10 iter, 5 runs):** High confidence for typical workload

### Reading Results

Example markdown output:
```markdown
| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `os [v14.1.1, 6.3M]` | 10.234 ± 0.123 | 10.098 | 10.356 | 1.04 ± 0.02 |
| `lto+pgo [v15.1.0, 3.8M]` | 9.876 ± 0.098 | 9.756 | 9.987 | 1.00 |
```

- **lto+pgo is baseline (1.00×)**
- **os is 1.04× slower (4% slower)**
- **lto+pgo has lower std dev (±0.098 vs ±0.123) = more consistent**
- **lto+pgo is 40% smaller (3.8M vs 6.3M)**

---

## Troubleshooting

### "No rg-* binaries found"
```bash
# Check BIN_DIR
ls -lh /proj_soc/user_dev/gczajkowski/bin/rg-*

# Set custom path
BIN_DIR=/custom/path ./benchmark-quick.sh
```

### "Dataset directory does not exist"
```bash
# Check dataset exists
ls -d /proj_soc/user_dev/gczajkowski/chiplet-template

# Use custom dataset
DATASET=/path/to/code ./benchmark-quick.sh
```

### "hyperfine is not installed"
```bash
cargo install hyperfine
```

### Benchmark taking too long
```bash
# Use quick benchmark instead
./benchmark-quick.sh

# Or set custom timeout (2 hours = 7200 seconds)
./benchmark-generic.sh ... --timeout 7200
```

---

## Files Created

```
tt/
├── verify-binaries.sh          # Quick functional test (30s)
├── benchmark-quick.sh          # Fast benchmark (15min)
├── benchmark-medium.sh          # Comprehensive (30min)
├── benchmark-long.sh          # Large dataset stress test (60min)
├── benchmark-claude.sh         # Claude workload simulation (40min)
├── benchmark-generic.sh        # Generic script (used by wrappers)
│
├── benchmark-results-quick/    # Quick benchmark results
├── benchmark-results-medium/    # medium results
├── benchmark-results-long/    # long results
└── benchmark-results-claude/   # Claude workload results
```

---

## Next Steps

After benchmarking:

1. **Review results:** Check markdown files for performance comparison
2. **Choose variant:** Use COMPREHENSIVE_BENCHMARK_ANALYSIS.md recommendations
3. **Deploy:** Copy chosen binary to production
4. **Monitor:** Track real-world performance

For production deployment, see:
- `COMPREHENSIVE_BENCHMARK_ANALYSIS.md` - Full analysis
- `BENCHMARK_QUICK_REFERENCE.md` - Quick reference tables
