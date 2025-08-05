#!/bin/bash

set -e

echo "🚀 Creating CoastSat Micropublication Release..."
echo ""

# Regenerate publication.crate  
echo "🏗️  Regenerating publication.crate..."
python3 src/crate_builder.py

# Generate HTML preview of the crate
echo "🌐 Generating HTML preview..."
if command -v rochtml >/dev/null 2>&1; then
    rochtml publication.crate/ro-crate-metadata.json
    echo "✅ HTML preview generated"
else
    echo "⚠️  rochtml not found, skipping HTML preview"
fi

# Create timestamp for release
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
crate_zip="micropublication-crate-${timestamp}.zip"

echo ""
echo "📋 Checking for changes..."

# Commit & push changes if any
if [[ -n $(git status --porcelain publication.crate) ]]; then
  commit_msg="Publish updated micropublication crate ($timestamp)"
  git add publication.crate
  git commit -m "$commit_msg"
  git push origin main
else
  echo "No changes in publication.crate to commit."
fi

# Create a release
release_tag="micropublication-crate-release-$timestamp"
gh release create "$release_tag" \
  --title "Micropublication Crate Release - $timestamp" \
  --notes "Auto-generated release for micropublication crate." \
  --target main

release_url=$(gh release view "$release_tag" --json url -q .url)

python3 scripts/patch_post_release.py "$release_url"
rochtml publication.crate/ro-crate-metadata.json
zip -r "$crate_zip" publication.crate
gh release upload "$release_tag" "$crate_zip" --clobber

gh release edit "$release_tag" --notes "Auto-generated release for micropublication crate.

📦 Release URL: $release_url"

# Clean up
rm "$crate_zip"