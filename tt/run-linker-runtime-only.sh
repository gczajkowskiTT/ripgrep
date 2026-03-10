#!/bin/bash

BIN_DIR="/proj_soc/user_dev/gczajkowski/bin"
RESULTS_DIR="/proj_soc/user_dev/gczajkowski/ripgrepTT/tt/linker-benchmark-results"
DATASET="/proj_soc/user_dev/gczajkowski/chiplet-template"

PATTERN="error"
PATTERN_NAME="literal"

echo "Running runtime benchmarks for linker comparison binaries only..."

# Only benchmark the linker-specific binaries
for binary in "$BIN_DIR"/rg-lto-thin-* "$BIN_DIR"/rg-lto-pgo-mimalloc-pcre2-dynamic-* "$BIN_DIR"/rg-lto-pgo-bolt-v3-mimalloc-pcre2-dynamic-*; do
    if [[ -f "$binary" && -x "$binary" ]]; then
        name=$(basename "$binary" | sed 's/^rg-//')
        echo "Benchmarking: $name"
        
        output_json="$RESULTS_DIR/runtime-${name}-${PATTERN_NAME}.json"
        
        hyperfine \
            --warmup 2 \
            --runs 5 \
            --export-json "$output_json" \
            "$binary --no-config --no-ignore $PATTERN '$DATASET'" \
            > "$RESULTS_DIR/runtime-${name}-${PATTERN_NAME}.log" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "  ✓ Completed"
        else
            echo "  ✗ Failed"
        fi
    fi
done

echo "Runtime benchmarks completed!"
