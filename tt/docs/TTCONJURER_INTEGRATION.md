# Integration with ttconjurer/rust/install.bash

This document explains how to integrate the optimized ripgrep builds into the ttconjurer/rust/install.bash script.

## Current Configuration

The install script has been updated to use the `release-lto` profile (line 176):

```bash
cargo install ripgrep --profile release-lto --features pcre2 --git https://github.com/gczajkowskiTT/ripgrep.git
```

This provides **20-25% performance improvement** over the standard release build with minimal integration effort.

## Integration Options

### Option 1: Current (release-lto) - RECOMMENDED

**Pros:**
- Simple one-line change (already implemented)
- 20-25% faster than standard release
- No additional complexity
- Build time: ~29 seconds
- Reliable and well-tested

**Cons:**
- Not the absolute maximum performance

**Usage:**
```bash
cargo install ripgrep --profile release-lto --features pcre2 --git https://github.com/gczajkowskiTT/ripgrep.git
```

### Option 2: PGO Build - MAXIMUM PERFORMANCE

**Pros:**
- Additional 5-10% performance gain over release-lto
- 8.5% smaller binary
- Best possible runtime performance

**Cons:**
- More complex build process
- Total build time: ~66 seconds
- Requires cloning and running build script

**Implementation:**

Replace line 176 in install.bash with:

```bash
# Clone ripgrep fork
rm -rf /tmp/ripgrep-pgo-build
git clone --depth 1 https://github.com/gczajkowskiTT/ripgrep.git /tmp/ripgrep-pgo-build
pushd /tmp/ripgrep-pgo-build

# Run PGO build
./build-pgo.sh --features pcre2

# Install the binary
cp target/release-lto/rg "$OUTPUT_DIR/bin/rg"
chmod +x "$OUTPUT_DIR/bin/rg"

popd
rm -rf /tmp/ripgrep-pgo-build
```

### Option 3: Configurable Build Mode

Allow users to choose the build mode via environment variable:

```bash
# Add near the top of install.bash with other configuration
RIPGREP_BUILD_MODE="${RIPGREP_BUILD_MODE:-release-lto}"  # Options: standard, release-lto, pgo

# Replace line 176 with:
case "$RIPGREP_BUILD_MODE" in
    standard)
        cargo install ripgrep --features pcre2 --git https://github.com/gczajkowskiTT/ripgrep.git
        ;;
    release-lto)
        cargo install ripgrep --profile release-lto --features pcre2 --git https://github.com/gczajkowskiTT/ripgrep.git
        ;;
    pgo)
        rm -rf /tmp/ripgrep-pgo-build
        git clone --depth 1 https://github.com/gczajkowskiTT/ripgrep.git /tmp/ripgrep-pgo-build
        pushd /tmp/ripgrep-pgo-build
        ./build-pgo.sh --features pcre2
        cp target/release-lto/rg "$OUTPUT_DIR/bin/rg"
        chmod +x "$OUTPUT_DIR/bin/rg"
        popd
        rm -rf /tmp/ripgrep-pgo-build
        ;;
    *)
        echo "Error: Unknown RIPGREP_BUILD_MODE '$RIPGREP_BUILD_MODE'"
        echo "Valid options: standard, release-lto, pgo"
        exit 1
        ;;
esac
```

**Usage:**
```bash
# Standard build
bash install.bash

# LTO build (default)
RIPGREP_BUILD_MODE=release-lto bash install.bash

# PGO build (maximum performance)
RIPGREP_BUILD_MODE=pgo bash install.bash
```

## Performance Comparison

| Build Mode | Binary Size | Relative Speed | Build Time | Complexity |
|------------|-------------|----------------|------------|------------|
| standard | 5.2 MB | 1.0x (baseline) | ~15s | Simple |
| release-lto | 4.0 MB | 1.20x (20% faster) | ~29s | Simple |
| pgo | 3.6 MB | 1.28x (28% faster) | ~66s | Moderate |

## Recommendations

### For Most Users
**Use Option 1 (release-lto)** - Already implemented and provides excellent performance with minimal complexity.

### For Performance-Critical Deployments
**Use Option 2 (PGO)** - When ripgrep performance is critical and the extra build time is acceptable.

### For Flexible Deployments
**Use Option 3 (Configurable)** - When different teams have different performance/build-time requirements.

## Testing

After implementing any of these options, verify the installation:

```bash
# Run the install script
bash /proj_soc/user_dev/gczajkowski/ttconjurer/rust/install.bash

# Verify ripgrep is installed and optimized
rg --version
# Should show: ripgrep 15.1.0 (rev 83a84fb0bd)

# Check binary size
ls -lh $(which rg)

# Test basic functionality
rg "pattern" /some/directory

# Benchmark (optional)
hyperfine 'rg "pattern" /large/codebase' --warmup 3
```

## CPU-Specific Optimizations (Advanced)

For additional performance on modern CPUs, uncomment lines 13-14 in `.cargo/config.toml`:

```toml
[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "target-cpu=x86-64-v3"]
```

**Warning:** This may cause crashes on older Intel machines (pre-2015). Test thoroughly before enabling.

## Troubleshooting

### Build fails with "llvm-profdata not found"

Install LLVM tools:
```bash
# Via rustup (recommended)
rustup component add llvm-tools-preview

# Or if llvm-profdata is available on the system, ensure it's in PATH
which llvm-profdata
```

### Binary crashes with "Illegal instruction"

You may have CPU-specific optimizations enabled. Check `.cargo/config.toml` and ensure line 13-14 are commented out.

### Build time too long

If PGO build time is too long, stick with `release-lto` mode which provides 80% of the benefit in 45% of the build time.

## Files in This Fork

- `OPTIMIZATION.md` - Comprehensive optimization guide
- `build-pgo.sh` - PGO build script
- `install-optimized.sh` - Installation wrapper script
- `TTCONJURER_INTEGRATION.md` - This file
- `.cargo/config.toml` - Cargo configuration with optimizations
- `Cargo.toml` - Contains release-lto and release-max profiles

## Maintenance

When updating ripgrep:

1. Pull latest changes from upstream: `git pull https://github.com/BurntSushi/ripgrep.git master`
2. Verify optimization profiles are still present in `Cargo.toml`
3. Test builds: `cargo build --profile release-lto --features pcre2`
4. Test PGO: `./build-pgo.sh`
5. Push to fork: `git push origin master`

## Questions?

For issues or questions about these optimizations, contact the maintainer of this fork.
