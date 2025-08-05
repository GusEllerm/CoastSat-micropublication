# Scripts Directory

This directory contains automation and deployment scripts for the CoastSat Micropublication System.

## Files

- `generate_publication.sh`: Quick script to generate a micropublication for a specific transect (legacy)
- `create_publication.sh`: Main script for building and releasing publication crates (legacy)
- `patch_post_release.py`: Post-release processing and metadata updates (legacy)

## Usage

All scripts should be run from the project root directory:

```bash
# Generate a micropublication for a specific transect (legacy)
./scripts/generate_publication.sh aus0001

# Create and release a publication crate (legacy)
./scripts/create_publication.sh
```

## Modern Alternatives

For current functionality, use the main commands instead:

```bash
# Modern micropublication generation
python src/publication_logic.py nzd0001-0001 --populate-crate

# Modern interface.crate building  
python src/crate_builder.py --interface-crate latest

# Modern comparison testing
./tests/test_publication_compare.sh nzd0001-0001 latest interface.crate-d61c2052a-20250725024714
```
