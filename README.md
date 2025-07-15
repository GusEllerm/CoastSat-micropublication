# CoastSat Micropublication

This project explores the integration of LivePublication micropublications with [CoastSat](https://github.com/UoA-eResearch/CoastSat). The goal is to generate procedural, data-driven micropublications for individual coastal transects and link them interactively to a map-based interface powered by `leaflet.glify`.

## Project Structure

- `CoastSat/`: Submodule containing a fork of the [CoastSat](https://github.com/UoA-eResearch/CoastSat) repo, with a branch used for micropublication integration with its `leaflet.glify` map.
- `interface.crate/`: Describes the computational processes and data used in the experiment (not yet populated).
- `publication.crate/`: Will contain per-transect micropublications built using [Stencila](https://stenci.la/) and informed by `interface.crate`.
- `docs/`: Static site directory (to be used with GitHub Pages) for testing the interactive map interface.

## Setup

This repository uses Git submodules. To clone:

```bash
git clone --recurse-submodules https://github.com/YOUR_USERNAME/CoastSat-micropublication.git
```

## License

MIT License.
