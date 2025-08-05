#!/bin/bash

set -e

# Default to a test transect if none provided
TRANSECT_ID=${1:-"nzd0314-0137"}
INTERFACE_CRATE_VERSION=${2:-"latest"}

echo "🧪 Testing micropublication generation for transect: $TRANSECT_ID"

# Generate the publication crate
echo "📦 Building publication crate..."
if [ "$INTERFACE_CRATE_VERSION" = "latest" ]; then
    python3 src/crate_builder.py
else
    echo "📦 Using interface.crate version: $INTERFACE_CRATE_VERSION"
    python3 src/crate_builder.py --interface-crate "$INTERFACE_CRATE_VERSION"
fi

# Generate micropublication for the specified transect
echo "📄 Generating micropublication..."
python3 src/publication_logic.py "$TRANSECT_ID"

# Open the generated micropublication
if [[ -f "micropublication.html" ]]; then
    echo "✅ Micropublication generated successfully!"
    echo "🌐 Opening micropublication.html..."
    open micropublication.html
else
    echo "❌ Failed to generate micropublication.html"
    exit 1
fi

echo "🎉 Test completed!"

# Usage:
# ./tests/test_gen_micropublication.sh [TRANSECT_ID] [INTERFACE_CRATE_VERSION]
# Examples:
# ./tests/test_gen_micropublication.sh nzd0001-0001
# ./tests/test_gen_micropublication.sh nzd0001-0001 latest
# ./tests/test_gen_micropublication.sh nzd0001-0001 interface.crate-d61c2052a-20250725024714
#
# Test transects:
# nzd0361-0064 -- no change in data, NZ transect
# nzd0001-0001 -- Change in data, NZ transect  
# nzd0314-0137 -- change in data, but empty row appended