# Scripts Directory

This directory contains automation and deployment scripts for the CoastSat Micropublication System.

## Files

- `generate_publication.sh`: Quick script to generate a micropublication for a specific transect (legacy)
- `create_publication.sh`: Main script for building and releasing publication crates (legacy)
- `patch_post_release.py`: Post-release processing and metadata updates (legacy)
- `publish_to_docs.sh`: **NEW** - Generate and publish micropublications to GitHub Pages

## Usage

All scripts should be run from the project root directory:

```bash
# Generate a micropublication for a specific transect (legacy)
./scripts/generate_publication.sh aus0001

# Create and release a publication crate (legacy)
./scripts/create_publication.sh

# Publish a micropublication to GitHub Pages (new)
./scripts/publish_to_docs.sh nzd0001-0001
./scripts/publish_to_docs.sh nzd0001-0001 latest
./scripts/publish_to_docs.sh nzd0001-0001 interface.crate-d61c2052a-20250725024714
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

## GitHub Pages Publishing

The `publish_to_docs.sh` script provides a complete workflow for publishing micropublications to GitHub Pages:

### What it does:
1. **Builds interface.crate** with specified version
2. **Generates micropublication** with populated crate  
3. **Creates RO-Crate HTML preview** using rochtml
4. **Copies everything to docs/** directory
5. **Creates enhanced landing page** with links to both resources
6. **Prepares for GitHub Pages** deployment

### Requirements:
- `ro-crate-html-js` package: `npm install -g ro-crate-html-js`

### Example workflow:
```bash
# Generate and publish for specific transect
./scripts/publish_to_docs.sh nzd0001-0001

# Commit and push to GitHub
git add docs/
git commit -m "Publish nzd0001-0001 micropublication to GitHub Pages"
git push

# Enable GitHub Pages in repository settings (source: docs/ folder)
```

### Output:
- **`docs/index.html`** - Landing page with links to both resources
- **`docs/micropublication.html`** - Interactive micropublication  
- **`docs/ro-crate-preview.html`** - RO-Crate metadata browser
- **`docs/ro-crate-metadata.json`** - Complete research object metadata
