#!/bin/bash

set -e
python publication_crate.py
rochtml publication.crate/ro-crate-metadata.json

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
crate_zip="publication.crate-${timestamp}.zip"
zip -r "$crate_zip" publication.crate

# Commit & push
if [[ -n $(git status --porcelain publication.crate) ]]; then
  commit_msg="Publish updated publication.crate ($timestamp)"
  git add publication.crate
  git commit -m "$commit_msg"
  git push origin main
else
  echo "No changes in publication.crate to commit."
fi

# Create a release
release_tag="crate-release-$timestamp"
gh release create "$release_tag" \
  --title "Publication Crate Release - $timestamp" \
  --notes "Auto-generated release for publication.crate." \
  --target main \
  "$crate_zip"
  
# Clean up
rm "$crate_zip"