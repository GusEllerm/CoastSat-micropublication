#!/bin/bash

# Micropublication Comparison Tool - Interactive Version
# This script generates two micropublications with different interface.crate versions
# and creates a side-by-side comparison interface for easy analysis

# Set strict error handling
set -euo pipefail

# Configuration
DEFAULT_TRANSECT_ID="nzd0001-0001"
DEFAULT_OUTPUT_DIR="./comparison_output"
AUTO_OPEN=true

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Ensure we're in the right directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

show_help() {
    cat << EOF
🌊 Micropublication Comparison Tool

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --output-dir DIR    Specify output directory (default: ./comparison_output)
    --no-auto-open      Don't automatically open browser
    --help              Show this help message

EXAMPLES:
    $0                           # Interactive mode (recommended)
    $0 --output-dir ./my_comparison
    $0 --help

DESCRIPTION:
    This tool generates two micropublications using different interface.crate versions
    and creates a side-by-side comparison interface. The comparison includes:
    
    • Visual diff highlighting changes between versions
    • Synchronized scrolling between both versions
    • File size comparison
    • Interactive controls for detailed analysis
    
    In interactive mode, you'll be prompted to:
    1. Select a transect ID from available options
    2. Choose from the latest interface.crate versions available on GitHub
    3. Specify which two versions to compare
    
    The script automatically fetches available versions from the GitHub repository.

EOF
}

fetch_available_versions() {
    echo -e "${BLUE}📡 Fetching available interface.crate versions from GitHub...${NC}" >&2
    
    # First try to fetch from the interface.crate repository
    local releases_json
    if releases_json=$(curl -s "https://api.github.com/repos/GusEllerm/CoastSat-interface.crate/releases?per_page=15" 2>/dev/null); then
        local versions
        if versions=$(echo "$releases_json" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\([^"]*\)"/\1/' | head -10 2>/dev/null); then
            if [ -n "$versions" ]; then
                echo "$versions"
                return
            fi
        fi
    fi
    
    echo -e "${YELLOW}⚠️  Could not fetch from interface.crate repository, trying main CoastSat repository...${NC}" >&2
    
    # Fallback to main CoastSat repository
    if releases_json=$(curl -s "https://api.github.com/repos/kvos/CoastSat/releases?per_page=15" 2>/dev/null); then
        local versions
        if versions=$(echo "$releases_json" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\([^"]*\)"/\1/' | head -10 2>/dev/null); then
            if [ -n "$versions" ]; then
                echo "$versions"
                return
            fi
        fi
    fi
    
    echo -e "${RED}❌ Failed to fetch releases from GitHub API${NC}" >&2
    echo -e "${YELLOW}💡 Please check your internet connection or try again later${NC}" >&2
    echo "" >&2
    echo "As a fallback, you can manually specify versions from the following examples:" >&2
    echo "  • latest" >&2
    echo "  • interface.crate-cb67e8e26-20250801011405" >&2
    echo "  • interface.crate-d61c2052a-20250725024714" >&2
    echo "" >&2
    exit 1
}

prompt_for_transect() {
    echo "" >&2
    echo -e "${CYAN}📍 Available transect options:${NC}" >&2
    echo "   • Format: SITE-TRANSECT (e.g., nzd0001-0001, aus0001-0001)" >&2
    echo "   • Australian coast: aus0001-XXXX to aus0089-XXXX" >&2
    echo "   • New Zealand coast: nzd0001-XXXX to nzd0999-XXXX" >&2
    echo "   • Custom transect ID" >&2
    echo "" >&2
    echo "Popular test transects:" >&2
    echo "   • nzd0361-0064 -- no change in data, NZ transect" >&2
    echo "   • nzd0001-0001 -- change in data, NZ transect" >&2
    echo "   • nzd0314-0137 -- change in data, but empty row appended" >&2
    echo "" >&2
    
    while true; do
        printf "${GREEN}Enter transect ID (default: $DEFAULT_TRANSECT_ID): ${NC}" >&2
        read -r input
        
        if [ -z "$input" ]; then
            echo "$DEFAULT_TRANSECT_ID"
            return
        fi
        
        if [[ "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "$input"
            return
        else
            echo -e "${RED}❌ Invalid transect ID format. Please use the format SITE-TRANSECT (e.g., nzd0001-0001).${NC}" >&2
        fi
    done
}

prompt_for_version() {
    local prompt_text="$1"
    local versions="$2"
    local exclude_version="$3"
    
    echo "" >&2
    echo -e "${CYAN}$prompt_text${NC}" >&2
    echo "Available versions:" >&2
    
    local i=1
    local version_array=()
    
    while IFS= read -r version; do
        if [ "$version" != "$exclude_version" ]; then
            echo "   $i) $version" >&2
            version_array+=("$version")
            ((i++))
        fi
    done <<< "$versions"
    
    echo "" >&2
    
    while true; do
        printf "${GREEN}Select version number (1-${#version_array[@]}): ${NC}" >&2
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#version_array[@]}" ]; then
            echo "${version_array[$((choice-1))]}"
            return
        else
            echo -e "${RED}❌ Invalid selection. Please enter a number between 1 and ${#version_array[@]}.${NC}" >&2
        fi
    done
}

generate_micropublication() {
    local version=$1
    local output_subdir=$2
    
    echo -e "${BLUE}📦 Generating micropublication for version: $version${NC}"
    
    # Path to the original micropublication_logic.py file (main repo)
    local original_logic="publication.crate/publication_logic.py"
    local interface_crate_dir="publication.crate/interface.crate"
    
    # Check if the original file exists
    if [ ! -f "$original_logic" ]; then
        echo -e "${RED}❌ micropublication_logic.py not found at $original_logic${NC}"
        echo -e "${YELLOW}💡 Make sure you're running this script from the project root directory${NC}"
        exit 1
    fi
    
    # Backup the current interface.crate directory
    local backup_dir="interface.crate.backup.$$"
    if [ -d "$interface_crate_dir" ]; then
        cp -r "$interface_crate_dir" "$backup_dir"
    fi
    
    # Download and extract the specified interface.crate version
    echo "   📥 Downloading interface.crate version: $version"
    local download_url="https://github.com/GusEllerm/CoastSat-interface.crate/releases/download/$version/interface-crate.zip"
    local temp_archive="interface-crate.$version.zip"
    
    if curl -L -o "$temp_archive" "$download_url" 2>/dev/null; then
        echo "   📦 Extracting interface.crate..."
        # Remove existing interface.crate directory
        rm -rf "$interface_crate_dir"
        # Extract the new version
        unzip -q "$temp_archive" -d "temp_extract/"
        # The zip should contain the interface.crate directory directly
        if [ -d "temp_extract/interface.crate" ]; then
            mv "temp_extract/interface.crate" "$interface_crate_dir"
            echo "   ✅ Successfully updated interface.crate to version $version"
        else
            # Fallback: look for any directory in the extracted content
            local extracted_dir=$(find temp_extract -maxdepth 1 -type d ! -name temp_extract | head -1)
            if [ -n "$extracted_dir" ]; then
                mv "$extracted_dir" "$interface_crate_dir"
                echo "   ✅ Successfully updated interface.crate to version $version"
            else
                echo -e "${RED}   ❌ Failed to find interface.crate directory in extracted archive${NC}"
                echo -e "${YELLOW}   💡 Falling back to existing interface.crate directory${NC}"
            fi
        fi
        rm -rf "temp_extract"
        rm -f "$temp_archive"
    else
        echo -e "${RED}   ❌ Failed to download interface.crate version $version${NC}"
        echo -e "${YELLOW}   💡 URL: $download_url${NC}"
        echo -e "${YELLOW}   💡 Falling back to existing interface.crate directory${NC}"
    fi
    
    echo "   Using interface.crate version: $version"
    echo "   Output: $output_subdir/"
    
    # Generate the micropublication (using the original script without modifications)
    if python3 "$original_logic" "$TRANSECT_ID" --output "$output_subdir/micropublication.html"; then
        echo -e "${GREEN}   ✅ Successfully generated micropublication${NC}"
    else
        echo -e "${RED}   ❌ Failed to generate micropublication${NC}"
        # Restore backup
        if [ -d "$backup_dir" ]; then
            rm -rf "$interface_crate_dir"
            mv "$backup_dir" "$interface_crate_dir"
        fi
        exit 1
    fi
    
    # Restore the original interface.crate directory
    if [ -d "$backup_dir" ]; then
        rm -rf "$interface_crate_dir"
        mv "$backup_dir" "$interface_crate_dir"
        echo "   🔄 Restored original interface.crate directory"
    fi
}

# Parse command line arguments
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-auto-open)
            AUTO_OPEN=false
            shift
            ;;
        --*)
            echo -e "${RED}🚫 Unknown option: $1${NC}"
            echo -e "${YELLOW}💡 Use --help for usage information${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}🚫 Unexpected argument: $1${NC}"
            echo -e "${YELLOW}💡 This tool now runs in interactive mode. Use --help for more information${NC}"
            exit 1
            ;;
    esac
done

# Welcome message
echo -e "${BLUE}🌊 Welcome to the Micropublication Comparison Tool!${NC}"
echo ""
echo "This tool will help you compare micropublications generated from different"
echo "interface.crate versions to understand how changes in the CoastSat experiment"
echo "affect the resulting publications."

# Fetch available versions
AVAILABLE_VERSIONS=$(fetch_available_versions)

if [ -z "$AVAILABLE_VERSIONS" ]; then
    echo -e "${RED}❌ No versions available for comparison${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found $(echo "$AVAILABLE_VERSIONS" | wc -l) available versions${NC}"

# Interactive prompts
TRANSECT_ID=$(prompt_for_transect)
VERSION_1=$(prompt_for_version "🔹 Select the FIRST version to compare:" "$AVAILABLE_VERSIONS" "")
VERSION_2=$(prompt_for_version "🔸 Select the SECOND version to compare:" "$AVAILABLE_VERSIONS" "$VERSION_1")

echo ""
echo -e "${CYAN}📋 Comparison Configuration:${NC}"
echo "   Transect ID: $TRANSECT_ID"
echo "   Version 1: $VERSION_1"
echo "   Version 2: $VERSION_2"
echo "   Output Directory: $OUTPUT_DIR"
echo ""

printf "${GREEN}Proceed with this configuration? (y/N): ${NC}" >&2
read -r confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Comparison cancelled by user${NC}"
    exit 0
fi

# Validate that versions are different
if [ "$VERSION_1" = "$VERSION_2" ]; then
    echo -e "${RED}❌ Cannot compare the same version with itself${NC}"
    echo "Please run the script again and select different versions"
    exit 1
fi

echo ""
echo -e "${BLUE}🔍 Starting CoastSat Micropublication Comparison${NC}"
echo "============================================"

# Create output directory structure
echo -e "${BLUE}📁 Setting up output directories...${NC}"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/version1"
mkdir -p "$OUTPUT_DIR/version2"

# Generate micropublications
echo ""
echo -e "${BLUE}🏗️  Generating micropublications...${NC}"

generate_micropublication "$VERSION_1" "$OUTPUT_DIR/version1"
echo ""
generate_micropublication "$VERSION_2" "$OUTPUT_DIR/version2"

echo ""

# Create comparison HTML page
echo -e "${BLUE}🎨 Creating comparison interface...${NC}"

# First, let's create a simple HTTP server script
cat > "$OUTPUT_DIR/start_server.py" << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
import webbrowser
import threading
import time
import socket
import subprocess
import signal

def find_process_using_port(port):
    """Find process ID using the specified port."""
    try:
        # Use lsof to find the process using the port
        result = subprocess.run(['lsof', '-ti', f':{port}'], 
                              capture_output=True, text=True, check=False)
        if result.stdout.strip():
            return int(result.stdout.strip().split('\n')[0])
        return None
    except (subprocess.SubprocessError, ValueError):
        return None

def kill_process_on_port(port):
    """Kill process using the specified port."""
    pid = find_process_using_port(port)
    if pid:
        try:
            print(f"🔍 Found existing server on port {port} (PID: {pid})")
            os.kill(pid, signal.SIGTERM)
            time.sleep(1)  # Give it time to shut down gracefully
            
            # Check if it's still running
            if find_process_using_port(port):
                print(f"⚠️  Process didn't stop gracefully, forcing...")
                os.kill(pid, signal.SIGKILL)
                time.sleep(0.5)
            
            print(f"✅ Stopped existing server (PID: {pid})")
            return True
        except (ProcessLookupError, PermissionError) as e:
            print(f"⚠️  Could not stop process {pid}: {e}")
            return False
    return False

def is_port_available(port):
    """Check if a port is available."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', port))
            return True
    except socket.error:
        return False

def find_available_port(start_port=8000, max_attempts=10):
    """Find an available port starting from start_port."""
    for port in range(start_port, start_port + max_attempts):
        if is_port_available(port):
            return port
    return None

def start_server(preferred_port=8000):
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    port = preferred_port
    
    # Check if preferred port is available
    if not is_port_available(port):
        print(f"🔍 Port {port} is in use...")
        
        # Try to kill existing server on this port
        if kill_process_on_port(port):
            # Wait a moment and check again
            time.sleep(1)
            if is_port_available(port):
                print(f"✅ Port {port} is now available")
            else:
                print(f"⚠️  Port {port} still not available, finding alternative...")
                port = find_available_port(port + 1)
        else:
            # Find an alternative port
            port = find_available_port(port + 1)
    
    if port is None:
        print("❌ Could not find an available port")
        sys.exit(1)
    
    if port != preferred_port:
        print(f"📡 Using alternative port {port} instead of {preferred_port}")
    
    class QuietHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, format, *args):
            pass  # Suppress log messages
    
    try:
        with socketserver.TCPServer(("", port), QuietHTTPRequestHandler) as httpd:
            print(f"🌐 Serving comparison at http://localhost:{port}")
            print("🔄 Server will stop automatically when you close the browser tab")
            print("⏹️  Or press Ctrl+C to stop manually")
            
            # Open browser after a short delay
            def open_browser():
                time.sleep(1)
                webbrowser.open(f'http://localhost:{port}/comparison.html')
            
            if len(sys.argv) > 1 and sys.argv[1] == "--open":
                browser_thread = threading.Thread(target=open_browser)
                browser_thread.daemon = True
                browser_thread.start()
            
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\n🛑 Server stopped")
    
    except socket.error as e:
        print(f"❌ Failed to start server on port {port}: {e}")
        print("💡 You may need to wait a moment for the port to be released")
        sys.exit(1)

if __name__ == "__main__":
    start_server()
EOF

chmod +x "$OUTPUT_DIR/start_server.py"

# Create the comparison HTML interface
cat > "$OUTPUT_DIR/comparison.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Micropublication Comparison - $TRANSECT_ID</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
        }
        
        .header {
            background: #2c3e50;
            color: white;
            padding: 15px;
            text-align: center;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 1000;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            margin: 0;
            font-size: 18px;
            font-weight: 600;
        }
        
        .version-info {
            margin-top: 5px;
            font-size: 12px;
            opacity: 0.8;
        }
        
        .sync-indicator {
            position: fixed;
            top: 80px;
            right: 20px;
            background: #27ae60;
            color: white;
            padding: 8px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 500;
            z-index: 1001;
            transition: all 0.3s ease;
        }
        
        .sync-indicator.disabled {
            background: #e74c3c;
        }
        
        .container {
            display: flex;
            height: 100vh;
            padding-top: 110px;
            padding-bottom: 60px;
            gap: 2px;
        }
        
        .panel {
            flex: 1;
            display: flex;
            flex-direction: column;
            background: white;
            border-radius: 8px;
            margin: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        
        .panel-header {
            background: #34495e;
            color: white;
            padding: 12px 20px;
            font-weight: 600;
            font-size: 14px;
            text-align: center;
        }
        
        .iframe-container {
            flex: 1;
            position: relative;
        }
        
        .iframe-container iframe {
            width: 100%;
            height: 100%;
            border: none;
            background: white;
        }
        
        .controls {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background: #ecf0f1;
            padding: 15px;
            text-align: center;
            border-top: 1px solid #bdc3c7;
            z-index: 1000;
        }
        
        .btn {
            background: #3498db;
            color: white;
            border: none;
            padding: 10px 20px;
            margin: 0 10px;
            border-radius: 5px;
            cursor: pointer;
            font-weight: 500;
            transition: background-color 0.3s ease;
        }
        
        .btn:hover {
            background: #2980b9;
        }
        
        .btn:active {
            transform: translateY(1px);
        }
        
        @media (max-width: 768px) {
            .container {
                flex-direction: column;
                padding-top: 120px;
            }
            
            .header h1 {
                font-size: 16px;
            }
            
            .version-info {
                font-size: 11px;
            }
            
            .btn {
                padding: 8px 15px;
                margin: 5px;
                font-size: 14px;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔬 Micropublication Comparison: $TRANSECT_ID</h1>
        <div class="version-info">
            <strong>Left:</strong> $VERSION_1 | 
            <strong>Right:</strong> $VERSION_2
        </div>
    </div>
    
    <div class="sync-indicator" id="syncIndicator">🔄 Synchronized Scrolling</div>
    
    <div class="container">
        <div class="panel">
            <div class="panel-header">$VERSION_1</div>
            <div class="iframe-container">
                <iframe id="iframe1" src="version1/micropublication.html"></iframe>
            </div>
        </div>
        
        <div class="panel">
            <div class="panel-header">$VERSION_2</div>
            <div class="iframe-container">
                <iframe id="iframe2" src="version2/micropublication.html"></iframe>
            </div>
        </div>
    </div>
    
    <div class="controls">
        <button class="btn" onclick="toggleSync()">Toggle Sync</button>
        <button class="btn" onclick="resetView()">Reset View</button>
        <button class="btn" onclick="openOriginals()">Open Originals</button>
    </div>
    
    <script>
        let syncEnabled = true;
        let isScrolling = false;
        let doc1, doc2;
        
        const iframe1 = document.getElementById('iframe1');
        const iframe2 = document.getElementById('iframe2');
        const syncIndicator = document.getElementById('syncIndicator');
        
        function getIframeDocument(iframe) {
            try {
                return iframe.contentDocument || iframe.contentWindow.document;
            } catch (e) {
                console.log('Cannot access iframe content due to security restrictions');
                return null;
            }
        }
        
        function setupSyncScrolling() {
            // Wait for both iframes to load
            let iframe1Loaded = false;
            let iframe2Loaded = false;
            
            iframe1.onload = function() {
                iframe1Loaded = true;
                doc1 = getIframeDocument(iframe1);
                if (iframe1Loaded && iframe2Loaded) {
                    attachScrollListeners();
                }
            };
            
            iframe2.onload = function() {
                iframe2Loaded = true;
                doc2 = getIframeDocument(iframe2);
                if (iframe1Loaded && iframe2Loaded) {
                    attachScrollListeners();
                }
            };
        }
        
        function attachScrollListeners() {
            if (!doc1 || !doc2) {
                console.log('Cannot attach scroll listeners - iframe access restricted');
                // Hide sync indicator if we can't sync
                syncIndicator.style.display = 'none';
                return;
            }
            
            console.log('Setting up synchronized scrolling...');
            
            // Debounce function to smooth out rapid scroll events
            function debounce(func, wait) {
                let timeout;
                return function executedFunction(...args) {
                    const later = () => {
                        clearTimeout(timeout);
                        func(...args);
                    };
                    clearTimeout(timeout);
                    timeout = setTimeout(later, wait);
                };
            }
            
            // Smooth scroll sync function - same speed, not same position
            function syncScroll(sourceDoc, targetDoc) {
                if (!syncEnabled || isScrolling) return;
                
                isScrolling = true;
                
                try {
                    // Get source scroll position (absolute pixels)
                    const sourceScrollTop = sourceDoc.documentElement.scrollTop || sourceDoc.body.scrollTop || 0;
                    
                    // Get target document height info for bounds checking
                    const targetScrollHeight = targetDoc.documentElement.scrollHeight || targetDoc.body.scrollHeight || 1;
                    const targetClientHeight = targetDoc.documentElement.clientHeight || targetDoc.body.clientHeight || 1;
                    const maxTargetScroll = Math.max(0, targetScrollHeight - targetClientHeight);
                    
                    // Use the same absolute scroll position (same speed scrolling)
                    // But cap it at the maximum possible scroll for the target document
                    const targetScrollTop = Math.min(sourceScrollTop, maxTargetScroll);
                    
                    // Apply scroll directly with same pixel position
                    if (targetDoc.documentElement && typeof targetDoc.documentElement.scrollTop !== 'undefined') {
                        targetDoc.documentElement.scrollTop = targetScrollTop;
                    } else if (targetDoc.body) {
                        targetDoc.body.scrollTop = targetScrollTop;
                    }
                    
                    console.log(\`Same-speed sync: \${sourceScrollTop}px -> \${targetScrollTop}px (max: \${maxTargetScroll}px)\`);
                    
                } catch (e) {
                    console.log('Error syncing scroll:', e);
                }
                
                // Reset scrolling flag after a brief delay
                setTimeout(() => { 
                    isScrolling = false; 
                }, 50);
            }
            
            // Create debounced sync functions
            const syncToDoc2 = debounce(() => syncScroll(doc1, doc2), 16); // ~60fps
            const syncToDoc1 = debounce(() => syncScroll(doc2, doc1), 16);
            
            // Add scroll listeners with improved event handling
            const doc1ScrollHandler = function() {
                if (syncEnabled && !isScrolling) {
                    syncToDoc2();
                }
            };
            
            const doc2ScrollHandler = function() {
                if (syncEnabled && !isScrolling) {
                    syncToDoc1();
                }
            };
            
            doc1.addEventListener('scroll', doc1ScrollHandler, { passive: true });
            doc2.addEventListener('scroll', doc2ScrollHandler, { passive: true });
            
            console.log('Synchronized scrolling enabled with smooth debouncing');
        }
        
        function toggleSync() {
            syncEnabled = !syncEnabled;
            syncIndicator.textContent = syncEnabled ? '🔄 Synchronized Scrolling' : '⏸️ Sync Disabled';
            syncIndicator.className = syncEnabled ? 'sync-indicator' : 'sync-indicator disabled';
            console.log('Sync toggled:', syncEnabled);
        }
        
        function resetView() {
            console.log('Resetting view...');
            
            // Temporarily disable sync to avoid conflicts
            const wasEnabled = syncEnabled;
            syncEnabled = false;
            
            try {
                // Smooth scroll to top for both documents
                if (doc1) {
                    if (doc1.documentElement && typeof doc1.documentElement.scrollTop !== 'undefined') {
                        doc1.documentElement.scrollTo({ top: 0, behavior: 'smooth' });
                    } else if (doc1.body) {
                        doc1.body.scrollTo({ top: 0, behavior: 'smooth' });
                    }
                }
                
                if (doc2) {
                    if (doc2.documentElement && typeof doc2.documentElement.scrollTop !== 'undefined') {
                        doc2.documentElement.scrollTo({ top: 0, behavior: 'smooth' });
                    } else if (doc2.body) {
                        doc2.body.scrollTo({ top: 0, behavior: 'smooth' });
                    }
                }
                
                console.log('View reset successfully with smooth scrolling');
                
                // Re-enable sync after smooth scroll completes
                setTimeout(() => {
                    syncEnabled = wasEnabled;
                }, 1000);
                
            } catch (e) {
                console.log('Cannot reset view - iframe access restricted:', e);
                // Fallback: reload the iframes
                iframe1.src = iframe1.src;
                iframe2.src = iframe2.src;
                console.log('Reloaded iframes as fallback');
                
                // Re-enable sync immediately for fallback
                syncEnabled = wasEnabled;
            }
        }
        
        function openOriginals() {
            window.open('version1/micropublication.html', '_blank');
            window.open('version2/micropublication.html', '_blank');
        }
        
        // Initialize when page loads
        window.addEventListener('load', setupSyncScrolling);
        
        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            if (e.ctrlKey || e.metaKey) {
                switch(e.key) {
                    case 's':
                        e.preventDefault();
                        toggleSync();
                        break;
                    case 'r':
                        e.preventDefault();
                        resetView();
                        break;
                    case 'o':
                        e.preventDefault();
                        openOriginals();
                        break;
                }
            }
        });
    </script>
</body>
</html>
EOF

# Get file sizes for comparison report
if [ -f "$OUTPUT_DIR/version1/micropublication.html" ] && [ -f "$OUTPUT_DIR/version2/micropublication.html" ]; then
    SIZE_1=$(ls -lh "$OUTPUT_DIR/version1/micropublication.html" | awk '{print $5}')
    SIZE_2=$(ls -lh "$OUTPUT_DIR/version2/micropublication.html" | awk '{print $5}')
    
    echo ""
    echo -e "${CYAN}📊 File size comparison:${NC}"
    echo "   Version 1 ($VERSION_1): $SIZE_1"
    echo "   Version 2 ($VERSION_2): $SIZE_2"
fi

echo -e "${GREEN}✅ Comparison interface created successfully!${NC}"
echo ""

# Handle auto-open or provide manual instructions
if [ "$AUTO_OPEN" = true ]; then
    echo -e "${BLUE}🚀 Starting HTTP server and opening comparison interface...${NC}"
    echo -e "${YELLOW}📝 Note: Using HTTP server to avoid browser security restrictions${NC}"
    echo ""
    
    # Check if port 8000 is already in use and offer to clean it up
    if lsof -ti :8000 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port 8000 appears to be in use (likely from a previous comparison)${NC}"
        echo -e "${BLUE}🔧 The server will automatically handle this and use an available port${NC}"
        echo ""
    fi
    
    # Start the server with auto-open
    cd "$OUTPUT_DIR"
    python3 start_server.py --open &
    SERVER_PID=$!
    
    # Wait a moment for the server to start and determine the port
    sleep 2
    
    # Try to determine what port is being used
    ACTUAL_PORT=$(lsof -ti :8000 >/dev/null 2>&1 && echo "8000" || (
        for port in 8001 8002 8003 8004 8005; do
            if lsof -ti :$port >/dev/null 2>&1; then
                echo "$port"
                break
            fi
        done
    ))
    
    if [ -n "$ACTUAL_PORT" ]; then
        echo -e "${GREEN}✅ Server started (PID: $SERVER_PID) on port $ACTUAL_PORT${NC}"
        echo -e "${BLUE}🌐 Comparison available at: http://localhost:$ACTUAL_PORT/comparison.html${NC}"
    else
        echo -e "${GREEN}✅ Server started (PID: $SERVER_PID)${NC}"
        echo -e "${BLUE}🌐 Check the server output above for the actual port number${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}💡 To stop the server later:${NC}"
    echo "   Method 1: kill $SERVER_PID"
    echo "   Method 2: Press Ctrl+C in the server terminal"
    echo "   Method 3: Close the browser tab (server will continue but you can stop it manually)"
    
    # Go back to original directory
    cd - > /dev/null
else
    echo -e "${BLUE}ℹ️  Auto-open disabled. To view the comparison:${NC}"
    echo ""
    echo -e "${GREEN}Option 1 - Start HTTP server (recommended):${NC}"
    echo "   cd $OUTPUT_DIR && python3 start_server.py --open"
    echo ""
    echo -e "${YELLOW}Option 2 - Direct file access (may have limitations):${NC}"
    echo "   file://$(pwd)/$OUTPUT_DIR/comparison.html"
    echo ""
    echo -e "${BLUE}💡 The HTTP server option avoids browser security restrictions${NC}"
    echo "   and will automatically handle port conflicts if they occur"
fi

echo ""
echo -e "${CYAN}🎯 Next steps:${NC}"
echo "   • The comparison interface will open automatically in your browser"
echo "   • Scroll through both micropublications to compare differences"
echo "   • Use the toggle sync button to enable/disable synchronized scrolling"
echo "   • Click 'Open Originals' to view micropublications in separate tabs"
echo "   • Check the comparison report above for file size differences"
echo ""
echo -e "${CYAN}⌨️  Keyboard shortcuts:${NC}"
echo "   • Ctrl/Cmd + S: Toggle sync"
echo "   • Ctrl/Cmd + R: Reset view"
echo "   • Ctrl/Cmd + O: Open originals"
echo ""
echo -e "${CYAN}🔧 Technical notes:${NC}"
echo "   • HTTP server runs on localhost:8000 to avoid browser security restrictions"
echo "   • Server will continue running until you stop it (Ctrl+C)"
echo "   • All files are served locally from your machine"
