#!/bin/bash

# Quick Publication Generation Script
# Generates a micropublication for a specified transect
# Usage: ./scripts/generate_publication.sh [TRANSECT_ID]
# Example: ./scripts/generate_publication.sh aus0001-0000

set -e

# Parse arguments
TRANSECT_ID="${1:-aus0001-0000}"

echo "🚀 Generating CoastSat micropublication for transect: $TRANSECT_ID"
echo ""

# Step 1: Generate the publication crate if needed
if [ ! -d "publication.crate" ]; then
    echo "📦 Building publication crate..."
    python3 src/crate_builder.py
else
    echo "📦 Publication crate exists, skipping build..."
fi

# Step 2: Generate micropublication
echo "📄 Generating micropublication for transect $TRANSECT_ID..."
python3 src/publication_logic.py "$TRANSECT_ID"

# Step 3: Check result
if [[ -f "micropublication.html" ]]; then
    echo "✅ Micropublication generated successfully!"
    echo "📝 Output: micropublication.html"
    echo ""
    echo "🌐 To view the publication, open: micropublication.html"
else
    echo "❌ Failed to generate micropublication"
    exit 1
fi

echo "🎉 Generation completed!"
