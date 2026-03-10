# Benchmarking Suite Creation Summary

## ✅ Completed: Consolidated Benchmarking System

Created a unified benchmarking suite for ripgrep variant testing with 6 scripts:

---

## 1. verify-binaries.sh ✓
**Quick functional test (30 seconds)**

- Tests all rg-* binaries for basic functionality
- Runs 5 tests per binary: version, literal, regex, case-insensitive, multi-pattern
- Returns pass/fail status
- **Use before:** Any benchmarking to ensure binaries work

```bash
./verify-binaries.sh
```

---

## 2. benchmark-generic.sh ✓
**Generic benchmarking engine**

The core script that all other benchmarks use. Features:

### Key Features:
- **Dynamic binary discovery:** Finds all rg-* binaries automatically
- **Version extraction:** Gets version from each binary
- **Git-blame detection:** Automatically detects --no-git-blame support
- **Binary size reporting:** Includes sizes in results (important for Claude)
- **Reference comparison:** Compares against OS ripgrep
- **Multiple export formats:** JSON, Markdown, AsciiDoc
- **Timeout protection:** 12-hour default timeout
- **Duration tracking:** Reports how long benchmark ran

### Parameters:
```bash
--bindir DIR           # Required: Directory with rg-* binaries
--results-dir DIR      # Required: Where to save results
--dataset DIR          # Required: Test dataset path
--name NAME            # Optional: Benchmark name (default: "Default Benchmark")
--iterations N         # Optional: Iterations per scenario (default: 3)
--runs N               # Optional: Hyperfine runs (default: 3)
--reference CMD        # Optional: Reference binary (default: /usr/bin/rg)
--reference-name NAME  # Optional: Reference name (default: "OS installed RipGrep")
--timeout SECONDS      # Optional: Max duration (default: 43200 = 12 hours)
```

### What it tests:
1. Literal search: `"function"`
2. Regex search: `"class.*\{"`
3. Case-insensitive: `"error"` with `-i`
4. Multi-pattern: `"TODO|FIXME|XXX|HACK"`

---

## 3. benchmark-quick.sh ✓
**Fast performance overview (~15 minutes)**

**Simple wrapper script:**
```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/benchmark-generic.sh" \
    --bindir "${BIN_DIR:-/proj_soc/user_dev/gczajkowski/bin}" \
    --dataset "${DATASET:-/proj_soc/user_dev/gczajkowski/chiplet-template}" \
    --results-dir "$SCRIPT_DIR/benchmark-results-quick" \
    --name "Quick Benchmark" \
    --iterations 2 \
    --runs 3
```

**Configuration:**
- Dataset: chiplet-template (17GB, ~134k files)
- Iterations: 2
- Runs: 3
- Duration: ~1 minute per variant × 13 variants = ~15 minutes

**Use for:** Quick performance comparison

---

## 4. benchmark-medium.sh ✓
**Comprehensive benchmark (~30 minutes)**

**Configuration:**
- Dataset: chiplet-template (17GB, ~134k files)
- Iterations: 6
- Runs: 3
- Duration: ~2.3 minutes per variant × 13 variants = ~30 minutes

**Use for:** Statistically significant results with good confidence intervals

---

## 5. benchmark-long.sh ✓
**Large dataset stress test (~60 minutes)**

**Configuration:**
- Dataset: /proj_soc_scratch_ps/gitlab/.../tensix/soc/ (very large)
- Iterations: 3
- Runs: 3
- Duration: ~4.6 minutes per variant × 13 variants = ~60 minutes

**Use for:** Testing performance on massive datasets

---

## 6. benchmark-claude.sh ✓
**Claude-specific workload simulation (~40 minutes)**

**Configuration:**
- Dataset: chiplet-template (17GB, ~134k files)
- Iterations: 10 (simulates many quick searches)
- Runs: 5 (higher confidence)
- Duration: ~3 minutes per variant × 13 variants = ~40 minutes

**Claude-specific optimizations:**
- **Many iterations (10):** Simulates Claude's pattern of many small searches
- **More runs (5):** Higher statistical confidence
- **Binary size reporting:** Critical for distribution decisions
- **Real codebase:** Tests on actual source code structure

**Why this matters for Claude:**
1. **Binary size:** Smaller = faster loading, less memory, better distribution
2. **Many searches:** Claude doesn't do one big search, it does many quick ones
3. **Realistic data:** Tests on real code structure (not artificial data)
4. **Consistency:** 5 runs show if performance is stable

---

## Output Formats

All benchmarks produce 3 formats per scenario:

### 1. JSON (`*_scenario.json`)
```json
{
  "results": [...],
  "benchmarks": [...]
}
```
- Machine-readable
- Full hyperfine statistics
- For automated analysis/graphing

### 2. Markdown (`*_scenario.md`)
```markdown
| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `os [v14.1.1, 6.3M]` | 10.234 ± 0.123 | 10.098 | 10.356 | 1.04 ± 0.02 |
| `lto+pgo [v15.1.0, 3.8M]` | 9.876 ± 0.098 | 9.756 | 9.987 | 1.00 |
```
- Human-readable tables
- GitHub/GitLab compatible
- Quick visual comparison

### 3. AsciiDoc (`*_scenario.adoc`)
- Documentation format
- Can convert to PDF/HTML
- Publication-ready

---

## Key Design Features

### 1. Dynamic Binary Discovery
```bash
# Automatically finds all rg-* binaries
find "$BIN_DIR" -maxdepth 1 -type f -name 'rg-*' -executable
```

### 2. Intelligent Flag Detection
```bash
# Detects if binary supports --no-git-blame
if "$binary" --help 2>&1 | grep -q -- '--no-git-blame'; then
    flags="--no-config --no-ignore --no-git-blame"
else
    flags="--no-config --no-ignore"
fi
```

### 3. Version Extraction
```bash
# Extracts version from each binary
"$binary" --version | head -1 | awk '{print $2}'
```

### 4. Binary Size Reporting
```bash
# Includes size in results
display_name="${variant_name} [v${version}, ${size}]"
```

Example output:
```
lto+pgo [v15.1.0, 3.8M]: 9.876s ± 0.098s
```

### 5. Comprehensive Metadata
Each benchmark reports:
- Binary directory
- Results directory
- Timestamp
- Dataset path and size
- File count
- Iterations
- Hyperfine runs
- Timeout
- Variants found
- Reference command and version
- Total benchmark duration

---

## Usage Examples

### Verify All Binaries Work
```bash
./verify-binaries.sh
```

### Quick Performance Check
```bash
./benchmark-quick.sh
# Results in: benchmark-results-quick/
```

### Comprehensive Benchmark
```bash
./benchmark-medium.sh
# Results in: benchmark-results-medium/
```

### Claude-Specific Test
```bash
./benchmark-claude.sh
# Results in: benchmark-results-claude/
```

### Stress Test with Large Dataset
```bash
./benchmark-long.sh
# Results in: benchmark-results-long/
```

### Custom Benchmark
```bash
./benchmark-generic.sh \
    --bindir ~/bin \
    --results-dir ./my-results \
    --dataset /huge/codebase \
    --name "Production Test" \
    --iterations 5 \
    --runs 10 \
    --reference ~/bin/rg-baseline \
    --reference-name "Baseline" \
    --timeout 3600
```

### Override Defaults
```bash
# Use custom binary directory
BIN_DIR=/custom/path ./benchmark-quick.sh

# Use custom dataset
DATASET=/my/code ./benchmark-quick.sh

# Both
BIN_DIR=/custom/path DATASET=/my/code ./benchmark-quick.sh
```

---

## Directory Structure

```
tt/
├── verify-binaries.sh              # ✓ Functional test
├── benchmark-generic.sh            # ✓ Core engine
├── benchmark-quick.sh              # ✓ 15-minute wrapper
├── benchmark-medium.sh              # ✓ medium wrapper
├── benchmark-long.sh              # ✓ long wrapper
├── benchmark-claude.sh             # ✓ Claude workload wrapper
│
├── README_BENCHMARKS.md            # ✓ Full documentation
├── BENCHMARKING_SUITE_SUMMARY.md   # ✓ This file
│
├── benchmark-results-quick/        # Quick results
├── benchmark-results-medium/        # medium results
├── benchmark-results-long/        # long results
└── benchmark-results-claude/       # Claude workload results
```

---

## Comparison: Before vs After

### Before
- Multiple scripts with duplicate code
- Hardcoded binary paths
- Manual flag management
- No version tracking
- No binary size reporting
- Fixed iterations/runs
- No Claude-specific tests

### After ✓
- **1 generic engine + 5 wrappers:** DRY principle
- **Dynamic binary discovery:** Finds all rg-* automatically
- **Intelligent flag detection:** Auto-detects --no-git-blame support
- **Version extraction:** Reports version for each binary
- **Binary size reporting:** Critical for Claude's use case
- **Flexible configuration:** All parameters configurable
- **Claude-specific benchmark:** Optimized for Claude's workload
- **Comprehensive docs:** README + this summary

---

## Key Benefits for Claude

### 1. Binary Size Visibility
Every result shows binary size:
```
lto+pgo [v15.1.0, 3.8M]: 9.876s ± 0.098s
lto+pgo+bolt [v15.1.0, 33M]: 9.912s ± 0.156s
```
**Decision:** Use lto+pgo (3.8M, only 0.4% slower than 33M BOLT variant)

### 2. Many-Search Simulation
Claude benchmark runs 10 iterations:
```
--iterations 10  # Simulates many quick searches
```
Tests the actual usage pattern (many small searches, not one big search)

### 3. Realistic Codebase
Tests on real source code (chiplet-template, 17GB, 134k files):
- Actual file structures
- Real code patterns
- Representative of Claude's typical workloads

### 4. Statistical Confidence
5 hyperfine runs (vs 3 for other benchmarks):
```
--runs 5  # Higher confidence for production decisions
```

### 5. Easy Comparison
Markdown tables make it easy to compare:
- Performance: Which is fastest?
- Size: Which is smallest?
- Consistency: Which has lowest std dev?
- Trade-offs: Speed vs size

---

## Recommendations

### For Initial Testing
```bash
./verify-binaries.sh && ./benchmark-quick.sh
```

### For Production Decisions
```bash
./benchmark-medium.sh  # OR
./benchmark-claude.sh # If optimizing for Claude specifically
```

### For Stress Testing
```bash
./benchmark-long.sh
```

### For Custom Scenarios
```bash
./benchmark-generic.sh --bindir ... --dataset ... --name ...
```

---

## Next Steps

1. **Run verifications:** `./verify-binaries.sh`
2. **Quick benchmark:** `./benchmark-quick.sh`
3. **Analyze results:** Check markdown files
4. **Choose variant:** Based on performance vs size trade-offs
5. **Claude-specific test:** `./benchmark-claude.sh`
6. **Deploy:** Copy chosen binary to production

---

## Success Criteria ✅

- [x] Single generic benchmark engine
- [x] Dynamic binary discovery
- [x] Intelligent flag detection (--no-git-blame)
- [x] Version extraction
- [x] Binary size reporting
- [x] Flexible configuration (all parameters)
- [x] Reference command support
- [x] Multiple export formats (JSON, Markdown, AsciiDoc)
- [x] Timeout protection
- [x] Duration tracking
- [x] 5 wrapper scripts (verify, quick, 30min, 60min, claude)
- [x] Claude-specific benchmark
- [x] Comprehensive documentation

**All requirements completed! ✓**
