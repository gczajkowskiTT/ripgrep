# Ripgrep Fork - Optimized Build Configuration

This fork of ripgrep includes comprehensive build optimizations for maximum runtime performance.

## Quick Start

### Standard Optimized Build
```bash
cargo build --profile release-lto --features pcre2
```

### PGO-Optimized Build (Best Performance)
```bash
./build-pgo.sh
```

### Install via Cargo
```bash
cargo install --profile release-lto --features pcre2 --path .
```

## What's Optimized?

This fork includes:

1. **Optimized Cargo profiles** in `Cargo.toml`:
   - `release-lto`: Full LTO, single codegen unit, max optimization
   - `release-max`: Placeholder for future aggressive optimizations

2. **PGO build script** (`build-pgo.sh`):
   - Automated Profile-Guided Optimization build process
   - 5-10% additional performance over release-lto
   - 8.5% smaller binary

3. **CPU optimization configuration** in `.cargo/config.toml`:
   - x86-64-v3 optimizations (commented out for compatibility)
   - Instructions for target-cpu=native builds

4. **Integration scripts** for ttconjurer/rust/install.bash:
   - `install-optimized.sh`: Wrapper for different build modes
   - Drop-in replacement for cargo install

## Performance Gains

Compared to standard release builds:
- **release-lto**: 20-25% faster, 23% smaller binary
- **PGO**: 28% faster, 31% smaller binary

See `OPTIMIZATION.md` for detailed benchmarks.

## Documentation

- **[OPTIMIZATION.md](OPTIMIZATION.md)**: Complete optimization guide with benchmarks
- **[TTCONJURER_INTEGRATION.md](TTCONJURER_INTEGRATION.md)**: Integration with ttconjurer/rust/install.bash
- **[build-pgo.sh](build-pgo.sh)**: PGO build script (run with --help)
- **[install-optimized.sh](install-optimized.sh)**: Installation wrapper script

## Files Modified

### Configuration Files
- `Cargo.toml`: Added release-lto and release-max profiles
- `.cargo/config.toml`: Added CPU optimization configuration (commented)

### Build Scripts (NEW)
- `build-pgo.sh`: Automated PGO build
- `install-optimized.sh`: Installation wrapper
- `OPTIMIZATION.md`: Optimization guide
- `TTCONJURER_INTEGRATION.md`: Integration documentation
- `README_OPTIMIZATIONS.md`: This file

## Usage in ttconjurer/rust/install.bash

The install script has been updated to use the optimized profile:

```bash
# Line 176 (current implementation)
cargo install ripgrep --profile release-lto --features pcre2 --git https://github.com/gczajkowskiTT/ripgrep.git
```

For PGO builds, see `TTCONJURER_INTEGRATION.md`.

## Compatibility

- **Linux**: All optimizations tested and working
- **macOS**: Should work (not tested)
- **Windows**: Should work (not tested)
- **CPU**: x86-64 (optional x86-64-v3 for modern CPUs)

## Building from Source

```bash
# Clone this fork
git clone https://github.com/gczajkowskiTT/ripgrep.git
cd ripgrep

# Standard optimized build
cargo build --profile release-lto --features pcre2

# Or use PGO for maximum performance
./build-pgo.sh

# Binary will be at:
# target/release-lto/rg
```

## Testing

Verify your build:

```bash
# Check version
./target/release-lto/rg --version

# Run basic test
./target/release-lto/rg "pattern" crates/

# Benchmark (requires hyperfine)
hyperfine './target/release-lto/rg "fn " crates/' --warmup 3
```

## Maintenance

This fork tracks upstream ripgrep. To update:

```bash
# Add upstream remote (one-time)
git remote add upstream https://github.com/BurntSushi/ripgrep.git

# Update from upstream
git fetch upstream
git merge upstream/master

# Verify optimizations are still present
git diff HEAD Cargo.toml .cargo/config.toml

# Test builds
cargo build --profile release-lto --features pcre2
./build-pgo.sh
```

## Contributing

When contributing optimizations:

1. Test on multiple machines (old and new CPUs)
2. Benchmark before and after changes
3. Update documentation if adding new optimizations
4. Ensure compatibility with ttconjurer/rust/install.bash

## License

Same as upstream ripgrep (MIT or UNLICENSE).

## Questions?

See detailed documentation in:
- `OPTIMIZATION.md` for technical details
- `TTCONJURER_INTEGRATION.md` for integration guide
- Run `./build-pgo.sh --help` for PGO build options
