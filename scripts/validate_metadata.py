#!/usr/bin/env python3
"""Validate metadata files and cross-file consistency."""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    print("❌ Missing dependency: pyyaml. Install with `pip install pyyaml`.")
    sys.exit(2)

TITLE = "CoastSat transect micropublication LivePublication"
LICENSE_TOKEN = "CC-BY-4.0"
ORCID_BARE = "0000-0001-8260-231X"
ORCID_URL = f"https://orcid.org/{ORCID_BARE}"

REQUIRED_FILES = [
    "README.md",
    "LICENSE",
    "CITATION.cff",
    "codemeta.json",
    ".zenodo.json",
    "ro-crate-metadata.json",
    "scripts/generate_ro_crate.py",
    "scripts/validate_metadata.py",
]


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def normalize_license(value) -> str | None:
    if not value:
        return None
    if isinstance(value, dict):
        value = value.get("@id") or value.get("id") or value.get("license")
    if isinstance(value, list):
        for item in value:
            normalized = normalize_license(item)
            if normalized:
                return normalized
        return None
    value = str(value)
    if LICENSE_TOKEN in value:
        return LICENSE_TOKEN
    if "creativecommons.org/licenses/by/4.0" in value:
        return LICENSE_TOKEN
    return value


def ensure(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    errors: list[str] = []

    for relative_path in REQUIRED_FILES:
        ensure(
            (repo_root / relative_path).exists(),
            f"Missing required file: {relative_path}",
            errors,
        )

    if errors:
        for error in errors:
            print(f"❌ {error}")
        sys.exit(1)

    citation = load_yaml(repo_root / "CITATION.cff")
    codemeta = load_json(repo_root / "codemeta.json")
    zenodo = load_json(repo_root / ".zenodo.json")
    ro_crate = load_json(repo_root / "ro-crate-metadata.json")

    titles = [
        citation.get("title"),
        codemeta.get("name"),
        zenodo.get("title"),
    ]

    graph = ro_crate.get("@graph", [])
    graph_index = {entity.get("@id"): entity for entity in graph if "@id" in entity}
    root_dataset = graph_index.get("./")
    metadata_descriptor = graph_index.get("ro-crate-metadata.json")

    ensure(root_dataset is not None, "RO-Crate missing root dataset ./", errors)
    ensure(metadata_descriptor is not None, "RO-Crate missing metadata descriptor", errors)

    if root_dataset:
        titles.append(root_dataset.get("name"))

    ensure(all(title == TITLE for title in titles), "Title mismatch across metadata", errors)

    citation_license = normalize_license(citation.get("license"))
    codemeta_license = normalize_license(codemeta.get("license"))
    zenodo_license = normalize_license(zenodo.get("license"))
    rocrate_license = normalize_license(root_dataset.get("license") if root_dataset else None)

    ensure(citation_license == LICENSE_TOKEN, "CITATION license is not CC-BY-4.0", errors)
    ensure(codemeta_license == LICENSE_TOKEN, "CodeMeta license is not CC-BY-4.0", errors)
    ensure(zenodo_license == LICENSE_TOKEN, "Zenodo license is not CC-BY-4.0", errors)
    ensure(rocrate_license == LICENSE_TOKEN, "RO-Crate license is not CC-BY-4.0", errors)

    citation_authors = citation.get("authors", []) or []
    citation_orcids = {author.get("orcid") for author in citation_authors if author}
    ensure(
        ORCID_URL in citation_orcids,
        "CITATION.cff missing required ORCID",
        errors,
    )

    codemeta_authors = codemeta.get("author", []) or []
    codemeta_orcids = {author.get("@id") for author in codemeta_authors if author}
    ensure(
        ORCID_URL in codemeta_orcids,
        "CodeMeta missing required ORCID",
        errors,
    )

    zenodo_creators = zenodo.get("creators", []) or []
    zenodo_orcids = {creator.get("orcid") for creator in zenodo_creators if creator}
    ensure(
        ORCID_BARE in zenodo_orcids,
        "Zenodo metadata missing required ORCID",
        errors,
    )

    if root_dataset:
        main_entity_id = root_dataset.get("mainEntity", {}).get("@id")
        main_entity = graph_index.get(main_entity_id) if main_entity_id else None
        main_authors = []
        if main_entity:
            main_author = main_entity.get("author")
            if isinstance(main_author, list):
                main_authors = main_author
            elif main_author:
                main_authors = [main_author]
        main_orcids = {author.get("@id") for author in main_authors if isinstance(author, dict)}
        ensure(
            ORCID_URL in main_orcids,
            "RO-Crate mainEntity missing required ORCID",
            errors,
        )

    if metadata_descriptor:
        conforms_to = metadata_descriptor.get("conformsTo")
        conforms_list = []
        if isinstance(conforms_to, list):
            conforms_list = conforms_to
        elif conforms_to:
            conforms_list = [conforms_to]
        conforms_ids = {item.get("@id") for item in conforms_list if isinstance(item, dict)}
        ensure(
            "https://w3id.org/ro/crate/1.1" in conforms_ids,
            "RO-Crate metadata descriptor missing conformsTo 1.1",
            errors,
        )
        about = metadata_descriptor.get("about", {})
        ensure(
            isinstance(about, dict) and about.get("@id") == "./",
            "RO-Crate metadata descriptor does not reference root dataset",
            errors,
        )

    descriptions = [
        citation.get("abstract"),
        codemeta.get("description"),
        zenodo.get("description"),
    ]
    if root_dataset:
        descriptions.append(root_dataset.get("description"))
    if root_dataset and root_dataset.get("mainEntity"):
        main_entity = graph_index.get(root_dataset.get("mainEntity", {}).get("@id"))
        if main_entity:
            descriptions.append(main_entity.get("description"))

    for text in descriptions:
        if isinstance(text, str) and "..." in text:
            errors.append("Descriptions or abstracts contain truncation (" + text + ")")
            break

    if errors:
        for error in errors:
            print(f"❌ {error}")
        sys.exit(1)

    print("✅ Metadata validation passed")


if __name__ == "__main__":
    main()
