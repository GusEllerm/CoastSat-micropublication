# Tests Directory

This directory contains testing and validation scripts for the micropublication system.

## Files

- `test_gen_micropublication.sh`: Tests basic micropublication generation process
- `test_publication_compare.sh`: Comprehensive comparison tool for micropublications with different interface.crate versions

## Usage

Run tests from the project root directory:

```bash
# Test micropublication generation for a specific transect
./tests/test_gen_micropublication.sh nzd0001-0001

# Compare micropublications with different interface.crate versions (interactive mode)
./tests/test_publication_compare.sh

# Options for comparison script:
#   --output-dir DIR    Specify output directory (default: ./comparison_output)
#   --no-auto-open      Don't automatically open browser
#   --help              Show help message

# Example with custom output directory and no auto-open:
./tests/test_publication_compare.sh --output-dir ./my_comparison --no-auto-open
```

## Publication Comparison Features

The `test_publication_compare.sh` script provides:
- Side-by-side micropublication comparison
- Synchronized scrolling between versions
- HTTP server for proper local file access
- File size comparison reporting
- Automated browser opening (optional)
- Port conflict resolution

## Available Test Transects

- `nzd0361-0064` -- No change in data, NZ transect
- `nzd0001-0001` -- Change in data, NZ transect  
- `nzd0314-0137` -- Change in data, but empty row appended
