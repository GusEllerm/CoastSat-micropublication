# CoastSat Micropublication System

Generate interactive, reproducible research micropublications from CoastSat coastal transect analysis data using RO-Crate and Stencila technologies.

## 🚀 Quick Start

### Basic Usage

```bash
# Generate a micropublication for a specific transect
python src/publication_logic.py nzd0001-0001

# Generate and populate the publication crate
python src/publication_logic.py nzd0001-0001 --populate-crate

# Build interface.crate with latest version
python src/crate_builder.py

# Build interface.crate with specific version
python src/crate_builder.py --interface-crate interface.crate-d61c2052a-20250725024714
```

### Compare Publications

```bash
# Compare micropublications with different interface.crate versions
./tests/test_publication_compare.sh nzd0001-0001 latest interface.crate-d61c2052a-20250725024714
```

### Deploy to GitHub Pages

```bash
# Generate micropublication and publish to GitHub Pages
./scripts/publish_to_docs.sh nzd0001-0001

# Commit and deploy
git add docs/ && git commit -m "Publish micropublication" && git push
```

## 📋 Core Features

- **Dynamic Micropublications**: Executable documents with live code and coastal data analysis
- **RO-Crate Integration**: Research Object metadata for reproducibility and data packaging
- **Interface.crate Versioning**: Support for multiple interface.crate versions with automatic downloading
- **Publication Comparison**: Side-by-side comparison of micropublications with different versions
- **Transect-Specific Analysis**: Generate focused publications for individual coastal transects
- **Location Geocoding**: Automatic resolution of location names from coordinates
- **Automated Crate Population**: Update publication crates with generated content and metadata

## 🛠️ Commands Reference

### Core Generation Commands

| Task                              | Command                                                        |
| --------------------------------- | -------------------------------------------------------------- |
| Generate micropublication         | `python src/publication_logic.py [TRANSECT_ID]`               |
| Generate + populate crate         | `python src/publication_logic.py [TRANSECT_ID] --populate-crate` |
| Build interface.crate (latest)    | `python src/crate_builder.py`                                 |
| Build interface.crate (specific)  | `python src/crate_builder.py --interface-crate [VERSION]`     |

### Testing & Comparison Commands

| Task                              | Command                                                        |
| --------------------------------- | -------------------------------------------------------------- |
| Test generation                   | `./tests/test_gen_micropublication.sh [TRANSECT_ID]`          |
| Compare publications              | `./tests/test_publication_compare.sh [ID] [VER1] [VER2]`      |
| Compare with no auto-open         | `./tests/test_publication_compare.sh [ID] [VER1] [VER2] --no-open` |

### Legacy Commands (if available)

| Task                              | Command                                                        |
| --------------------------------- | -------------------------------------------------------------- |
| Quick generate (script)           | `./scripts/generate_publication.sh [TRANSECT_ID]`             |
| Create GitHub release             | `./scripts/create_publication.sh`                             |
| **Publish to GitHub Pages**       | `./scripts/publish_to_docs.sh [TRANSECT_ID] [VERSION]`        |

## 💡 Key Options & Features

### publication_logic.py Options
- `--output` - Specify output file path for generated micropublication HTML
- `--populate-crate` - Copy generated content to publication.crate and update metadata

### crate_builder.py Options  
- `--interface-crate` - Specify interface.crate version (e.g., "latest", "interface.crate-cb67e8e26-20250801011405")

### test_publication_compare.sh Options
- `--no-open` - Don't automatically open the comparison HTML in browser
- `--output-dir` - Directory to store comparison outputs (default: comparison_output)

### Supported Transect Types
- **NZD**: New Zealand transects (e.g., `nzd0001-0001`, `nzd0361-0064`)
- **AUS**: Australian transects (e.g., `aus0001-0001`)  
- **SAR**: Sardinia transects (e.g., `sar2541-0001`)

## 📁 Project Structure

- `src/`: Core application logic
  - `publication_logic.py`: Main micropublication generation logic with crate population
  - `crate_builder.py`: Interface.crate version management and RO-Crate building
  - `data/`: Transect data files and geospatial data
- `tests/`: Testing and validation scripts
  - `test_gen_micropublication.sh`: Basic generation testing
  - `test_publication_compare.sh`: Publication comparison tool with HTTP server
- `publication.crate/`: Generated RO-Crate containing micropublication artifacts
  - `interface.crate/`: Downloaded interface.crate with computational notebooks
  - `micropublication.html`: Generated HTML publication
  - `DNF_eval.json`: Evaluated document data
- `comparison_output/`: Generated comparison interfaces (created by test scripts)
- `CoastSat/`: Submodule containing CoastSat analysis tools and data
- `shoreline_project/`: Reference implementation and additional tools

## 🔄 Workflow Examples

### Basic Micropublication Generation
```bash
# Generate micropublication for a New Zealand transect
python src/publication_logic.py nzd0001-0001

# View the generated micropublication.html in your browser
```

### Publication with Crate Population
```bash
# Generate micropublication and update the publication crate
python src/publication_logic.py nzd0361-0064 --populate-crate

# The publication.crate/ directory now contains updated metadata and content
```

### Version Comparison Workflow  
```bash
# Compare publications generated with different interface.crate versions
./tests/test_publication_compare.sh nzd0001-0001 latest interface.crate-d61c2052a-20250725024714

# Opens browser with side-by-side comparison interface
# Use synchronized scrolling to compare differences
```

### Interface.crate Management
```bash
# Build with latest interface.crate version
python src/crate_builder.py

# Build with specific interface.crate version  
python src/crate_builder.py --interface-crate interface.crate-cb67e8e26-20250801011405

# List available versions
curl -s "https://api.github.com/repos/GusEllerm/CoastSat-interface.crate/releases" | grep '"tag_name"' | head -10
```

## 🔗 Integration

This project integrates with:
- **CoastSat**: For coastal analysis data and processing
- **Stencila**: For dynamic document generation and DNF processing
- **RO-Crate**: For research object packaging and metadata management
- **GitHub API**: For interface.crate version management and downloads
- **OpenStreetMap Nominatim**: For location geocoding from coordinates
- **HTTP Server**: For local comparison interface hosting

## 🧪 Testing

All major functionality has been comprehensively tested:
- ✅ Basic micropublication generation across transect types (NZD, AUS, SAR)
- ✅ --populate-crate flag functionality with metadata updates
- ✅ Interface.crate version management (latest and specific versions)  
- ✅ Publication comparison script with HTML interface generation
- ✅ Location geocoding and coordinate resolution
- ✅ Error handling for invalid versions and missing data

## 📄 License

MIT License.
