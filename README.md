# PVTR Action Test

This repository contains tests for the PVTR (Privateer) action and fixes for common SARIF upload issues.

## SARIF Upload Fix

This repository includes a fix for the common CodeQL SARIF upload error:
```
Invalid request. 1 item required; only 0 were supplied.
```

### Root Cause

This error occurs when the SARIF file has an empty `runs` array or missing required properties. While the SARIF file may pass local validation, GitHub's CodeQL API has stricter requirements.

### Solution

The `validate-sarif.sh` script:

1. **Validates** the SARIF file structure
2. **Detects** empty runs arrays that cause the upload error
3. **Fixes** malformed SARIF files by adding a minimal valid run structure
4. **Preserves** existing valid SARIF files unchanged

### Usage

The workflow automatically uses the validation script before uploading SARIF files:

```yaml
- name: Validate and fix SARIF file
  id: fix_sarif
  run: |
    if ! command -v jq &> /dev/null; then
      sudo apt-get update && sudo apt-get install -y jq
    fi
    ./validate-sarif.sh "${{ steps.scan.outputs.sarif_file }}"

- name: Upload SARIF file
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: ${{ steps.fix_sarif.outputs.sarif_file }}
    category: OSPS Baseline
```

### Manual Usage

```bash
./validate-sarif.sh path/to/file.sarif
```

The script will either:
- Output the original file path if valid
- Create a fixed version and output the fixed file path

### Files

- `.github/workflows/action-test.yml` - Main workflow that runs the PVTR scanner
- `validate-sarif.sh` - SARIF validation and fixing script