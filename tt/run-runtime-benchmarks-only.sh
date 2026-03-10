#!/bin/bash

BIN_DIR="/proj_soc/user_dev/gczajkowski/bin"
RESULTS_DIR="/proj_soc/user_dev/gczajkowski/ripgrepTT/tt/linker-benchmark-results"
DATASET="/proj_soc/user_dev/gczajkowski/chiplet-template"

PATTERN="error"
PATTERN_NAME="literal"

echo "Running runtime benchmarks for all existing binaries..."

for binary in "$BIN_DIR"/rg-*; do
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
    fi
done

echo "Runtime benchmarks completed!"
