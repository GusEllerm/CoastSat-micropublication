
from rocrate.rocrate import ROCrate, ContextEntity, Dataset
from rocrate.model.person import Person
from pathlib import Path
import argparse
import subprocess
import requests
import zipfile
import os
import io
import re
import shutil
import hashlib

def add_research_article(crate):
    main_article = crate.add(ContextEntity(crate, "#research-article", properties={
        "@type": "ScholarlyArticle",
        "name": "LivePublication: A Dynamic and Reproducible Research Article",
        "description": "Headless publication.crate; does not contain a main article",
    }))

    # TODO: Add author, date, and other metadata

    return main_article

def add_eval_dnf(crate):
    evaluated_document = crate.add(ContextEntity(crate, "#dnf-evaluated-document", properties={
        "@type": ["CreativeWork", "SoftwareSourceCode"],
        "name": "Evaluated DNF Document",
        "description": "Headless publicatoion.crate; does not contain evaluated DNF document"
    }))
    return evaluated_document

def add_dnf_presentation(crate):
    dnf_presentation_env = crate.add(ContextEntity(crate, "#dnf-presentation-environment", properties={
        "@type": "CreativeWork",
        "name": "DNF Presentation Environment",
        "description": "Environment responsible for converting the evaluated DNF document into presentation formats."
    }))

    return dnf_presentation_env

def add_dnf_schema(crate):
    wrapper = crate.get("#stencila-schema")

    return wrapper

def add_dnf_engine(crate):
    try:
        version_output = subprocess.check_output(["stencila", "--version"], text=True).strip()
    except Exception:
        version_output = "unknown"

    stencila_software = crate.add(ContextEntity(crate, "#stencila", properties={
        "@type": "SoftwareApplication",
        "name": "Stencila",
        "description": "The DNF Engine used to resolve the dynamic narrative.",
        "softwareVersion": version_output,
        "url": "https://github.com/stencila/stencila",
        "license": "https://www.apache.org/licenses/LICENSE-2.0",
        "howToUse": "https://github.com/stencila/stencila/blob/main/docs/reference/cli.md",
        "operatingSystem": "all"
    }))

    return stencila_software

def add_dnf_engine_spec(crate):
    try:
        version_output = subprocess.check_output(["stencila", "--version"], text=True).strip()
    except subprocess.CalledProcessError:
        version_output = "unknown"

    version_match = re.search(r"(\d+\.\d+\.\d+)", version_output)
    version_tag = f"v{version_match.group(1)}" if version_match else "main"

    stencila_spec = crate.add(ContextEntity(crate, "#stencila-schema", properties={
        "@type": "CreativeWork",
        "name": "Stencila DNF Engine Specification",
        "description": "Specification and JSON Schemas used by the Stencila DNF Engine to validate and interpret dynamic documents.",
        "url": f"https://github.com/stencila/stencila/tree/{version_tag}/schema",
        "license": "https://www.apache.org/licenses/LICENSE-2.0"
    }))

    return stencila_spec

def add_dnf_doc(crate):
    # Copy template from templates directory to working directory
    template_path = Path(__file__).parent / "templates" / "micropublication.smd"
    working_dir_template = Path("micropublication.smd")  # Keep specific template name
    
    if template_path.exists():
        shutil.copy(template_path, working_dir_template)
    
    sha256_hash = hashlib.sha256(open("micropublication.smd", "rb").read()).hexdigest() if os.path.exists("micropublication.smd") else ""
    dnf_file = crate.add_file("micropublication.smd", properties={
        "@type": ["File", "SoftwareSourceCode", "SoftwareApplication"],
        "name": "DNF Document File",
        "description": "The unresolved dynamic narrative document serving as input to the DNF Engine.",
        "encodingFormat": "application/smd",
        "sha256": sha256_hash
    })
    return dnf_file

def add_dnf_deps(crate, interface_crate_version="latest"):
    """
    Download and add interface.crate dependencies from GitHub releases.
    
    Args:
        crate: The ROCrate instance to add dependencies to
        interface_crate_version: Version to download ('latest' or specific tag)
    
    Returns:
        Dataset entity representing the nested interface.crate
    """
    repo_owner = "GusEllerm"
    repo_name = "CoastSat-interface.crate"
    download_dir = "."  # Extract to current working directory

    # Determine API URL based on version
    if interface_crate_version == "latest":
        api_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/releases/latest"
        print("📦 Fetching latest interface.crate release...")
    else:
        api_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/releases/tags/{interface_crate_version}"
        print(f"📦 Fetching interface.crate release: {interface_crate_version}...")

    token_path = Path(__file__).parent.parent / "token.txt"  # Go up from src/ to project root
    token = token_path.read_text().strip() if token_path.exists() else None

    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "CoastSat-micropublication"
    }
    if token:
        headers["Authorization"] = f"token {token}"
    
    try:
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        release = response.json()

        asset = next((a for a in release["assets"] if a["name"].endswith(".zip")), None)
        if not asset:
            if interface_crate_version == "latest":
                raise Exception("No zip asset found in the latest release.")
            else:
                raise Exception(f"No zip asset found in release {interface_crate_version}. Please check that the version exists and has a zip asset.")

        print(f"⬇️ Downloading: {asset['name']}")
        zip_response = requests.get(asset["browser_download_url"], headers=headers)
        zip_response.raise_for_status()

        with zipfile.ZipFile(io.BytesIO(zip_response.content)) as z:
            z.extractall(download_dir)  # Extracts to current working directory
            print(f"✅ Extracted to {download_dir}")

    except requests.exceptions.HTTPError as e:
        if hasattr(e, 'response') and e.response.status_code == 404:
            if interface_crate_version == "latest":
                raise Exception("Latest release not found. The repository may not have any releases.")
            else:
                raise Exception(f"Release {interface_crate_version} not found. Please check that the version exists.")
        else:
            raise Exception(f"HTTP error occurred: {e}")
    except Exception as e:
        if "Failed to download and extract interface.crate" not in str(e):
            raise Exception(f"Failed to download and extract interface.crate: {e}")
        else:
            raise e

    # Handle the case where the zip contains interface.crate/ directory
    # The zip may extract to interface.crate/interface.crate/ structure  
    extracted_interface_crate = os.path.join(download_dir, "interface.crate")
    if os.path.exists(extracted_interface_crate) and os.path.exists(os.path.join(extracted_interface_crate, "ro-crate-metadata.json")):
        # The zip contained interface.crate/ directory at root, we already have the right structure
        print("📁 Interface.crate extracted with correct structure")
    elif os.path.exists(os.path.join(extracted_interface_crate, "interface.crate", "ro-crate-metadata.json")):
        # The zip contained interface.crate/interface.crate/ - need to flatten
        inner_interface_crate = os.path.join(extracted_interface_crate, "interface.crate")
        temp_dir = os.path.join(download_dir, "temp_interface_crate")
        shutil.move(inner_interface_crate, temp_dir)
        shutil.rmtree(extracted_interface_crate)
        shutil.move(temp_dir, extracted_interface_crate)
        print("📁 Reorganized nested interface.crate directory structure")
    else:
        raise Exception("interface.crate directory structure is unexpected after extraction.")

    if not os.path.isdir("interface.crate"):
        raise Exception("interface.crate directory is missing after extraction.")

    nested = crate.add(Dataset(crate, "interface.crate/", properties={
        "name": "Interface Crate",
        "@type": ["RO-Crate", "Dataset"],
        "description": "Nested interface.crate containing Experiment Infrastructure execution data.",
        "license": "https://creativecommons.org/licenses/by/4.0/"
    }))

    return nested

def add_publication_logic(crate):
    # Copy publication logic from src directory to working directory  
    src_logic_path = Path(__file__).parent / "publication_logic.py"
    working_dir_logic = Path("publication_logic.py")  # Use consistent naming with shoreline_project
    
    if src_logic_path.exists():
        shutil.copy(src_logic_path, working_dir_logic)
    
    logic_file = crate.add_file("publication_logic.py", properties={
        "@type": ["File", "SoftwareSourceCode"],
        "name": "Publication Logic",
        "description": "Python logic for generating publications from the DNF document.",
        "encodingFormat": "text/x-python",
        "sha256": hashlib.sha256(open("publication_logic.py", "rb").read()).hexdigest()
    })
    return logic_file

def create_publication_crate(crate_dir="publication.crate", interface_crate_version="latest"):
    """
    Create a complete publication crate with all necessary components.
    
    Args:
        crate_dir: Directory to create the publication crate in
        interface_crate_version: Version of interface.crate to download
    
    Returns:
        None (writes crate to disk)
    """
    crate = ROCrate()
    crate.name = "Micropublication Crate"
    crate.description = "This crate contains the interface.crate and a Stencila DNF document for generating micropublications."
    creator = crate.add(Person(crate, "#creator", {"name": "Unknown Author"}))
    crate.creator = creator

    # Add relations
    dnf_document = add_dnf_doc(crate)
    dnf_engine = add_dnf_engine(crate)
    dnf_engine_spec = add_dnf_engine_spec(crate)
    dnf_data_dependencies = add_dnf_deps(crate, interface_crate_version)
    dnf_engine_schema = add_dnf_schema(crate)
    dnf_eval_doc = add_eval_dnf(crate)
    dnf_presentation_env = add_dnf_presentation(crate)
    research_article = add_research_article(crate)
    publication_logic = add_publication_logic(crate)

    print(dnf_presentation_env)

    crate.mainEntity = research_article
    # Note: Using type: ignore because static analysis incorrectly infers tuple types
    research_article["isBasedOn"] = [dnf_eval_doc, dnf_presentation_env]  # type: ignore
    research_article["wasGeneratedBy"] = [dnf_presentation_env, publication_logic]  # type: ignore

    dnf_eval_doc["isBasedOn"] = [dnf_document, dnf_data_dependencies, dnf_engine]  # type: ignore
    dnf_presentation_env["isBasedOn"] = [dnf_engine]  # type: ignore
    dnf_engine["isBasedOn"] = [dnf_engine_spec]  # type: ignore

    dnf_document["conformsTo"] = dnf_engine_spec  # type: ignore
    dnf_document["conformsTo"] = dnf_engine_schema  # type: ignore

    # Write to disk
    Path(crate_dir).mkdir(parents=True, exist_ok=True)
    
    # Before writing the crate, ensure the interface.crate directory is properly copied
    interface_crate_source = "interface.crate"
    interface_crate_dest = os.path.join(crate_dir, "interface.crate")
    
    if os.path.exists(interface_crate_source) and os.path.exists(os.path.join(interface_crate_source, "ro-crate-metadata.json")):
        if os.path.exists(interface_crate_dest):
            shutil.rmtree(interface_crate_dest)
        shutil.copytree(interface_crate_source, interface_crate_dest)
        print(f"📋 Copied interface.crate to {interface_crate_dest}")
    
    crate.write(crate_dir)

    # Clean up temporary files and directories
    _cleanup_temporary_files()

def _cleanup_temporary_files():
    """Clean up temporary files created during crate building."""
    temp_files = [
        "micropublication.smd",
        "publication_logic.py"
    ]
    
    for file_path in temp_files:
        path = Path(file_path)
        if path.exists():
            path.unlink()

    # Clean up the downloaded interface.crate directory
    if os.path.isdir("interface.crate"):
        shutil.rmtree("interface.crate")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create a publication crate with optional custom interface.crate version")
    parser.add_argument(
        "--interface-crate", "-i",
        default="latest",
        help="Specify interface.crate version (e.g., v1.0.0, v2.1.3, or 'latest' for latest release)"
    )
    
    args = parser.parse_args()
    
    create_publication_crate(interface_crate_version=args.interface_crate)