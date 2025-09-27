#!/bin/bash

# validate-sarif.sh - Script to validate and fix SARIF files before CodeQL upload
# This addresses the "1 item required; only 0 were supplied" error

set -e

SARIF_FILE="$1"
FIXED_SARIF_FILE="${SARIF_FILE%.sarif}-fixed.sarif"

if [ -z "$SARIF_FILE" ]; then
    echo "Usage: $0 <sarif-file>"
    exit 1
fi

if [ ! -f "$SARIF_FILE" ]; then
    echo "Error: SARIF file '$SARIF_FILE' not found"
    exit 1
fi

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed"
    exit 1
fi

echo "Validating SARIF file: $SARIF_FILE"

# Check if the file is valid JSON
if ! jq empty "$SARIF_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in SARIF file"
    exit 1
fi

# Check for empty runs array - this is the most common cause of the error
RUNS_COUNT=$(jq '.runs | length' "$SARIF_FILE")
echo "Number of runs in SARIF: $RUNS_COUNT"

if [ "$RUNS_COUNT" -eq 0 ]; then
    echo "Warning: SARIF file has empty runs array. This will cause 'Item required; only 0 were supplied' error."
    echo "Creating minimal valid SARIF file..."
    
    # Create a valid SARIF with empty results but proper structure
    jq '.runs = [{
        "tool": {
            "driver": {
                "name": "OSPS Baseline Scanner",
                "version": "1.0.0",
                "informationUri": "https://github.com/revanite-io/pvtr-runner",
                "rules": []
            }
        },
        "results": [],
        "columnKind": "utf16CodeUnits"
    }]' "$SARIF_FILE" > "$FIXED_SARIF_FILE"
    
    echo "Fixed SARIF file created: $FIXED_SARIF_FILE"
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "sarif_file=$FIXED_SARIF_FILE" >> "$GITHUB_OUTPUT"
    else
        echo "sarif_file=$FIXED_SARIF_FILE"
    fi
    exit 0
fi

# Check each run for empty results and other issues
for ((i=0; i<RUNS_COUNT; i++)); do
    RESULTS_COUNT=$(jq ".runs[$i].results | length" "$SARIF_FILE")
    echo "Run $i has $RESULTS_COUNT results"
    
    # Check if tool.driver is properly defined
    TOOL_NAME=$(jq -r ".runs[$i].tool.driver.name // empty" "$SARIF_FILE")
    if [ -z "$TOOL_NAME" ]; then
        echo "Warning: Run $i missing tool.driver.name"
    fi
done

# If we get here, the SARIF appears valid for GitHub
echo "SARIF file appears valid for GitHub CodeQL upload"
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "sarif_file=$SARIF_FILE" >> "$GITHUB_OUTPUT"
else
    echo "sarif_file=$SARIF_FILE"
fi