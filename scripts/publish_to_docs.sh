#!/bin/bash

# Publication to Docs Script
# Generates a publication with populated crate and creates a GitHub Pages-ready docs/ directory
# Usage: ./scripts/publish_to_docs.sh [TRANSECT_ID] [INTERFACE_CRATE_VERSION]
# Examples: 
#   ./scripts/publish_to_docs.sh nzd0001-0001
#   ./scripts/publish_to_docs.sh nzd0001-0001 latest
#   ./scripts/publish_to_docs.sh aus0001-0001 interface.crate-d61c2052a-20250725024714

set -e  # Exit on any error

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "📖 CoastSat Micropublication GitHub Pages Publisher"
    echo ""
    echo "Usage: ./scripts/publish_to_docs.sh [TRANSECT_ID] [INTERFACE_CRATE_VERSION]"
    echo ""
    echo "Arguments:"
    echo "  TRANSECT_ID              Transect ID to generate publication for (default: nzd0001-0001)"
    echo "  INTERFACE_CRATE_VERSION  Interface.crate version to use (default: latest)"
    echo ""
    echo "Examples:"
    echo "  ./scripts/publish_to_docs.sh                                    # Use defaults"
    echo "  ./scripts/publish_to_docs.sh nzd0001-0001                       # Specific transect, latest version"
    echo "  ./scripts/publish_to_docs.sh aus0001-0001 latest                # Australian transect, latest version"
    echo "  ./scripts/publish_to_docs.sh sar2541-0001 interface.crate-d61c2052a-20250725024714"
    echo ""
    echo "Requirements:"
    echo "  - ro-crate-html-js: npm install -g ro-crate-html-js"
    echo ""
    echo "Output:"
    echo "  Creates docs/ directory with GitHub Pages-ready content including:"
    echo "  - index.html (landing page)"
    echo "  - micropublication.html (interactive publication)"
    echo "  - ro-crate-preview.html (metadata browser)"
    echo "  - ro-crate-metadata.json (research object metadata)"
    echo ""
    echo "After running, commit and push to deploy:"
    echo "  git add docs/ && git commit -m \"Publish [TRANSECT_ID]\" && git push"
    exit 0
fi

# Check if rochtml is available
if ! command -v rochtml >/dev/null 2>&1; then
    echo "❌ rochtml command not found"
    echo "💡 Please install ro-crate-html-js:"
    echo "   npm install -g ro-crate-html-js"
    exit 1
fi

# Parse arguments
TRANSECT_ID="${1:-nzd0001-0001}"
INTERFACE_CRATE_VERSION="${2:-latest}"

echo "🚀 Publishing CoastSat micropublication for transect: $TRANSECT_ID"
echo "🔢 Using interface.crate version: $INTERFACE_CRATE_VERSION"
echo ""

# Step 1: Build interface.crate with specified version
echo "📦 Step 1: Building interface.crate..."
if [ "$INTERFACE_CRATE_VERSION" = "latest" ]; then
    python src/crate_builder.py
else
    python src/crate_builder.py --interface-crate "$INTERFACE_CRATE_VERSION"
fi

if [ $? -ne 0 ]; then
    echo "❌ Failed to build interface.crate"
    exit 1
fi

echo "✅ Interface.crate built successfully"
echo ""

# Step 2: Generate publication with populated crate
echo "📝 Step 2: Generating micropublication with populated crate..."
python src/publication_logic.py "$TRANSECT_ID" --populate-crate

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate publication"
    exit 1
fi

echo "✅ Micropublication generated with populated crate"
echo ""

# Step 3: Generate RO-Crate HTML preview
echo "🌐 Step 3: Generating RO-Crate HTML preview..."
rochtml publication.crate/ro-crate-metadata.json

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate RO-Crate HTML preview"
    exit 1
fi

echo "✅ RO-Crate HTML preview generated"
echo ""

# Step 4: Prepare docs directory
echo "📁 Step 4: Preparing docs/ directory..."

# Clean existing docs directory
if [ -d "docs/" ]; then
    echo "🧹 Cleaning existing docs/ directory..."
    rm -rf docs/
fi

# Create fresh docs directory
mkdir -p docs/

# Step 5: Copy publication.crate contents to docs/
echo "📦 Step 5: Copying publication crate to docs/..."
cp -r publication.crate/* docs/

echo "✅ Publication crate copied to docs/"
echo ""

# Step 6: Set up GitHub Pages index
echo "🔄 Step 6: Setting up GitHub Pages index..."

if [ -f "docs/ro-crate-preview.html" ]; then
    mv docs/ro-crate-preview.html docs/index.html
    echo "✅ Renamed ro-crate-preview.html to index.html"
elif [ -f "docs/index.html" ]; then
    echo "✅ index.html already exists"
elif [ -f "docs/preview.html" ]; then
    mv docs/preview.html docs/index.html
    echo "✅ Renamed preview.html to index.html"
else
    echo "⚠️  No RO-Crate preview found, using micropublication.html as index..."
    if [ -f "docs/micropublication.html" ]; then
        cp docs/micropublication.html docs/index.html
        echo "✅ Copied micropublication.html to index.html"
    else
        echo "❌ No suitable HTML file found for GitHub Pages"
        echo "📋 Available HTML files in docs/:"
        ls -la docs/*.html 2>/dev/null || echo "   No HTML files found"
        exit 1
    fi
fi

echo ""

# Step 7: Create a landing page that showcases both the RO-Crate and micropublication
echo "🎨 Step 7: Creating enhanced landing page..."

# Create a comprehensive index.html that links to both resources
cat > docs/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CoastSat Micropublication - $TRANSECT_ID</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f8f9fa;
            color: #333;
        }
        
        .header {
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px 20px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            margin: 0 0 10px 0;
            font-size: 2.5rem;
        }
        
        .header p {
            margin: 0;
            font-size: 1.1rem;
            opacity: 0.9;
        }
        
        .cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: white;
            border-radius: 8px;
            padding: 25px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
        }
        
        .card h2 {
            margin: 0 0 15px 0;
            color: #667eea;
            font-size: 1.4rem;
        }
        
        .card p {
            margin: 0 0 20px 0;
            line-height: 1.6;
            color: #666;
        }
        
        .btn {
            display: inline-block;
            padding: 12px 24px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            font-weight: 500;
            transition: background-color 0.2s ease;
        }
        
        .btn:hover {
            background: #5a67d8;
        }
        
        .btn.secondary {
            background: #718096;
        }
        
        .btn.secondary:hover {
            background: #4a5568;
        }
        
        .meta {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-top: 20px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .meta h3 {
            margin: 0 0 15px 0;
            color: #333;
        }
        
        .meta-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .meta-item {
            display: flex;
            flex-direction: column;
        }
        
        .meta-label {
            font-size: 0.9rem;
            font-weight: 600;
            color: #666;
            margin-bottom: 5px;
        }
        
        .meta-value {
            font-size: 1rem;
            color: #333;
        }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #666;
            font-size: 0.9rem;
        }
        
        @media (max-width: 768px) {
            .cards {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .meta-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌊 CoastSat Micropublication</h1>
        <p>LivePublication for Transect $TRANSECT_ID</p>
    </div>
    
    <div class="cards">
        <div class="card">
            <h2>📊 Micropublication Article</h2>
            <p>
                View the interactive micropublication with live data analysis, 
                trend visualization, and narrative-driven insights for this coastal transect.
            </p>
            <a href="micropublication.html" class="btn">View Micropublication</a>
        </div>
        
        <div class="card">
            <h2>📦 Publication Crate</h2>
            <p>
                Explore the complete research package including metadata, data files, 
                computational workflows, and provenance information following FAIR principles.
            </p>
            <a href="ro-crate-preview.html" class="btn secondary">Browse RO-Crate</a>
        </div>
    </div>
    
    <div class="meta">
        <h3>📋 Publication Metadata</h3>
        <div class="meta-grid">
            <div class="meta-item">
                <div class="meta-label">Transect ID</div>
                <div class="meta-value">$TRANSECT_ID</div>
            </div>
            <div class="meta-item">
                <div class="meta-label">Interface.crate Version</div>
                <div class="meta-value">$INTERFACE_CRATE_VERSION</div>
            </div>
            <div class="meta-item">
                <div class="meta-label">Generated</div>
                <div class="meta-value">$(date '+%B %d, %Y at %I:%M %p')</div>
            </div>
            <div class="meta-item">
                <div class="meta-label">Data Format</div>
                <div class="meta-value">RO-Crate + Stencila DNF</div>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>
            Generated by the CoastSat <strong>LivePublication</strong> System.
        </p>
    </div>
</body>
</html>
EOF

# Ensure we also have the ro-crate-preview.html available
if [ ! -f "docs/ro-crate-preview.html" ] && [ -f "publication.crate/ro-crate-preview.html" ]; then
    cp publication.crate/ro-crate-preview.html docs/
fi

echo "✅ Enhanced landing page created"
echo ""

# Step 8: Clean up publication.crate directory (optional)
echo "🧹 Step 8: Cleaning up publication.crate directory..."
read -p "🤔 Remove publication.crate/ directory? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "publication.crate/" ]; then
        rm -rf publication.crate/
        echo "✅ Removed publication.crate/ directory"
    else
        echo "ℹ️  publication.crate/ directory not found"
    fi
else
    echo "ℹ️  Keeping publication.crate/ directory"
fi

echo ""

# Step 9: Summary and next steps
echo "🎉 GitHub Pages publication ready!"
echo ""
echo "📋 Summary:"
echo "   🌐 Landing Page: docs/index.html"
echo "   📄 Micropublication: docs/micropublication.html"
echo "   📦 RO-Crate Preview: docs/ro-crate-preview.html"
echo "   📊 Metadata: docs/ro-crate-metadata.json"
echo "   📁 Transect ID: $TRANSECT_ID"
echo "   🔢 Interface.crate: $INTERFACE_CRATE_VERSION"
echo ""
echo "🚀 Next steps to publish:"
echo "   1. git add docs/"
echo "   2. git commit -m \"Publish $TRANSECT_ID micropublication to GitHub Pages\""
echo "   3. git push"
echo "   4. Enable GitHub Pages in repository settings (source: docs/ folder)"
echo ""
echo "🌐 After enabling GitHub Pages, your publication will be available at:"
echo "   https://GusEllerm.github.io/CoastSat-micropublication/"
echo ""
echo "💡 The landing page provides links to both:"
echo "   • Interactive micropublication (primary research output)"
echo "   • RO-Crate browser (metadata and provenance explorer)"
echo ""
echo "✨ Done!"
