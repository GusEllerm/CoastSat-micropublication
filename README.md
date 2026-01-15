# CoastSat transect micropublication LivePublication [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18250845.svg)](https://doi.org/10.5281/zenodo.18250845)


## What this is

This repository contains the CoastSat transect micropublication LivePublication used in Chapter 6 of the thesis case study. It generates small, per-transect micropublications from CoastSat analysis outputs and packages them with RO-Crate metadata. The system is designed to support integration into interactive map and dashboard experiences by producing consistent, linkable artefacts per transect.

## What it outputs

- A populated publication crate in `publication.crate/` with RO-Crate metadata

## How to view

Live demo: https://gusellerm.github.io/CoastSat-micropublication/
To see this publication in its native environement within the CoastSat dashboard: https://coastsat.livepublication.org/

- Local render:
  1. `python src/publication_logic.py nzd0001-0001 --populate-crate`
  2. Open `micropublication.html` or browse `publication.crate/`.
- GitHub Pages build:
  1. `./scripts/publish_to_docs.sh nzd0001-0001`
  2. Open `docs/index.html`.

## How to run / generate micropublications
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Generate a micropublication for a transect
python src/publication_logic.py nzd0001-0001

# Generate and populate the publication crate
python src/publication_logic.py nzd0001-0001 --populate-crate
```

## Inputs & provenance
- CoastSat shoreline LivePublication (context): https://doi.org/10.5281/zenodo.18250478
- CoastSat interface.crate generation tool: https://doi.org/10.5281/zenodo.18250232
- LivePublication Interface Schemas (DPC/DSC): https://doi.org/10.5281/zenodo.18250033
- Upstream CoastSat baseline repository: https://github.com/UoA-eResearch/CoastSat

## How to cite

Use `CITATION.cff`. Zenodo DOI: https://doi.org/10.5281/zenodo.18250845

## License
CC BY 4.0 (see `LICENSE`).
