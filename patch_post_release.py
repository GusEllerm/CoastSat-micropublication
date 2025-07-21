import sys
from pathlib import Path
from rocrate.rocrate import ROCrate

if len(sys.argv) != 2:
    print("Usage: python patch_release_url.py <release_url>")
    sys.exit(1)

release_url = sys.argv[1]

# Dynamically resolve path to publication.crate/ relative to script location
SCRIPT_DIR = Path(__file__).resolve().parent
CRATE_DIR = SCRIPT_DIR / "publication.crate"

interface_crate = ROCrate(str(CRATE_DIR))

if interface_crate.mainEntity:
    interface_crate.mainEntity["url"] = release_url
else:
    print("❌ mainEntity not found in the crate.")
    sys.exit(1)

interface_crate.write(str(CRATE_DIR))