#!/usr/bin/env python3
"""Generate a minimal RO-Crate metadata file for this repository."""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path

from rocrate.rocrate import ROCrate

TITLE = "CoastSat transect micropublication LivePublication"
DESCRIPTION = (
    "LivePublication system that generates per-transect CoastSat micropublications "
    "and RO-Crate packages to support interactive map and dashboard integration."
)
LICENSE = "CC-BY-4.0"
VERSION = "micropublication-crate-release-2025-10-28_14-58-45"
ORCID = "https://orcid.org/0000-0001-8260-231X"
AUTHOR_NAME = "Augustus Ellerm"
MAIN_ENTITY_ID = "#coastsat-transect-micropublication"

HAS_PART_FILES = [
    "README.md",
    "LICENSE",
    "CITATION.cff",
    "codemeta.json",
    ".zenodo.json",
    "requirements.txt",
    "scripts/generate_ro_crate.py",
    "scripts/validate_metadata.py",
    "scripts/publish_to_docs.sh",
    "scripts/generate_publication.sh",
    "scripts/create_publication.sh",
    "src/publication_logic.py",
    "src/crate_builder.py",
    "src/templates/micropublication.smd",
    "micropublication.html",
]


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    os.chdir(repo_root)

    crate = ROCrate()
    root_dataset = crate.root_dataset
    root_dataset["name"] = TITLE
    root_dataset["description"] = DESCRIPTION
    root_dataset["license"] = LICENSE
    root_dataset["version"] = VERSION

    author = crate.add_jsonld(
        {
            "@id": ORCID,
            "@type": "Person",
            "name": AUTHOR_NAME,
            "givenName": "Augustus",
            "familyName": "Ellerm",
        }
    )

    main_entity = crate.add_jsonld(
        {
            "@id": MAIN_ENTITY_ID,
            "@type": "SoftwareSourceCode",
            "name": TITLE,
            "description": DESCRIPTION,
            "license": LICENSE,
            "version": VERSION,
            "author": author,
        }
    )
    root_dataset["mainEntity"] = main_entity

    crate.metadata["conformsTo"] = {"@id": "https://w3id.org/ro/crate/1.1"}

    for relative_path in HAS_PART_FILES:
        file_path = repo_root / relative_path
        if not file_path.exists():
            raise FileNotFoundError(f"Missing required file for RO-Crate: {relative_path}")
        crate.add_file(relative_path, dest_path=relative_path)

    with tempfile.TemporaryDirectory() as tmp_dir:
        crate.write(tmp_dir)
        metadata_path = Path(tmp_dir) / "ro-crate-metadata.json"
        ro_crate = json.loads(metadata_path.read_text(encoding="utf-8"))
        output_path = repo_root / "ro-crate-metadata.json"
        output_path.write_text(json.dumps(ro_crate, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
