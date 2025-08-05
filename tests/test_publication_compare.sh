#!/bin/bash

set -e  # Exit on any error

# Parse arguments
AUTO_OPEN=true
TRANSECT_ID=""
VERSION_1=""
VERSION_2=""
OUTPUT_DIR="comparison_output"

show_help() {
    echo "Usage: $0 <TRANSECT_ID> <VERSION_1> <VERSION_2> [--no-open] [--output-dir DIR] [--help]"
    echo ""
    echo "Compare micropublications generated with different interface.crate versions"
    echo ""
    echo "Arguments:"
    echo "  TRANSECT_ID     Transect ID to generate micropublications for (e.g., nzd0001-0001, nzd0314-0137)"
    echo "  VERSION_1       First interface.crate version (e.g., latest, interface.crate-cb67e8e26-20250801011405)"
    echo "  VERSION_2       Second interface.crate version for comparison"
    echo ""
    echo "Options:"
    echo "  --no-open       Don't automatically open the comparison HTML"
    echo "  --output-dir    Directory to store comparison outputs (default: comparison_output)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 nzd0001-0001 latest interface.crate-d61c2052a-20250725024714"
    echo "  $0 nzd0314-0137 interface.crate-cb67e8e26-20250801011405 interface.crate-d61c2052a-20250725024714 --no-open"
    echo ""
    echo "Available versions can be found with:"
    echo "  curl -s \"https://api.github.com/repos/GusEllerm/CoastSat-interface.crate/releases\" | grep '\"tag_name\"' | head -10"
    echo ""
    echo "Test transects:"
    echo "  nzd0361-0064 -- no change in data, NZ transect"
    echo "  nzd0001-0001 -- Change in data, NZ transect"
    echo "  nzd0314-0137 -- change in data, but empty row appended"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-open)
            AUTO_OPEN=false
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$TRANSECT_ID" ]; then
                TRANSECT_ID="$1"
            elif [ -z "$VERSION_1" ]; then
                VERSION_1="$1"
            elif [ -z "$VERSION_2" ]; then
                VERSION_2="$1"
            else
                echo "❌ Too many arguments provided"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$TRANSECT_ID" ] || [ -z "$VERSION_1" ] || [ -z "$VERSION_2" ]; then
    echo "❌ Missing required arguments"
    show_help
    exit 1
fi

if [ "$VERSION_1" = "$VERSION_2" ]; then
    echo "❌ Cannot compare the same version with itself"
    echo "Please provide two different interface.crate versions"
    exit 1
fi

echo "🔍 CoastSat Micropublication Comparison Tool"
echo "============================================"
echo "📍 Transect ID: $TRANSECT_ID"
echo "🔢 Version 1: $VERSION_1"
echo "🔢 Version 2: $VERSION_2"
echo "📂 Output Directory: $OUTPUT_DIR"
echo ""

# Create output directory structure
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/version1"
mkdir -p "$OUTPUT_DIR/version2"

# Function to generate micropublication with specific version
generate_micropublication() {
    local version=$1
    local output_subdir=$2
    local version_label=$3
    
    echo "🚀 Generating micropublication with $version_label ($version)..."
    
    # Clean up any existing publication.crate
    if [ -d "publication.crate" ]; then
        rm -rf publication.crate/
    fi
    
    # Generate publication crate with specified version
    if [ "$version" = "latest" ]; then
        timeout 300 python src/crate_builder.py || {
            echo "❌ Failed to build crate with $version_label"
            return 1
        }
    else
        timeout 300 python src/crate_builder.py --interface-crate "$version" || {
            echo "❌ Failed to build crate with $version_label"
            return 1
        }
    fi
    
    # Generate HTML micropublication
    python src/publication_logic.py "$TRANSECT_ID" || {
        echo "❌ Failed to generate micropublication with $version_label"
        return 1
    }
    
    # Copy results to output directory
    if [ -f "micropublication.html" ]; then
        cp "micropublication.html" "$OUTPUT_DIR/$output_subdir/micropublication.html"
        echo "✅ $version_label micropublication saved to $OUTPUT_DIR/$output_subdir/micropublication.html"
        
        # Get file size for comparison
        local file_size=$(ls -lh "micropublication.html" | awk '{print $5}')
        echo "📊 File size: $file_size"
    else
        echo "❌ HTML micropublication not generated for $version_label"
        return 1
    fi
}

# Generate micropublications
echo "🔧 Starting micropublication generation..."
echo ""

generate_micropublication "$VERSION_1" "version1" "Version 1"
echo ""
generate_micropublication "$VERSION_2" "version2" "Version 2"
echo ""

# Create comparison HTML page
echo "🎨 Creating comparison interface..."

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
    echo "📊 File size comparison:"
    echo "   Version 1 ($VERSION_1): $SIZE_1"
    echo "   Version 2 ($VERSION_2): $SIZE_2"
fi

echo "✅ Comparison interface created successfully!"
echo ""

# Handle auto-open or provide manual instructions
if [ "$AUTO_OPEN" = true ]; then
    echo "🚀 Starting HTTP server and opening comparison interface..."
    echo "📝 Note: Using HTTP server to avoid browser security restrictions"
    echo ""
    
    # Check if port 8000 is already in use and offer to clean it up
    if lsof -ti :8000 >/dev/null 2>&1; then
        echo "⚠️  Port 8000 appears to be in use (likely from a previous comparison)"
        echo "🔧 The server will automatically handle this and use an available port"
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
        echo "✅ Server started (PID: $SERVER_PID) on port $ACTUAL_PORT"
        echo "🌐 Comparison available at: http://localhost:$ACTUAL_PORT/comparison.html"
    else
        echo "✅ Server started (PID: $SERVER_PID)"
        echo "🌐 Check the server output above for the actual port number"
    fi
    
    echo ""
    echo "💡 To stop the server later:"
    echo "   Method 1: kill $SERVER_PID"
    echo "   Method 2: Press Ctrl+C in the server terminal"
    echo "   Method 3: Close the browser tab (server will continue but you can stop it manually)"
    
    # Go back to original directory
    cd - > /dev/null
else
    echo "ℹ️  Auto-open disabled. To view the comparison:"
    echo ""
    echo "Option 1 - Start HTTP server (recommended):"
    echo "   cd $OUTPUT_DIR && python3 start_server.py --open"
    echo ""
    echo "Option 2 - Direct file access (may have limitations):"
    echo "   file://$(pwd)/$OUTPUT_DIR/comparison.html"
    echo ""
    echo "💡 The HTTP server option avoids browser security restrictions"
    echo "   and will automatically handle port conflicts if they occur"
fi

echo ""
echo "🎯 Next steps:"
echo "   • The comparison interface will open automatically in your browser"
echo "   • Scroll through both micropublications to compare differences"
echo "   • Use the toggle sync button to enable/disable synchronized scrolling"
echo "   • Click 'Open Originals' to view micropublications in separate tabs"
echo "   • Check the comparison report above for file size differences"
echo ""
echo "⌨️  Keyboard shortcuts:"
echo "   • Ctrl/Cmd + S: Toggle sync"
echo "   • Ctrl/Cmd + R: Reset view"
echo "   • Ctrl/Cmd + O: Open originals"
echo ""
echo "🔧 Technical notes:"
echo "   • HTTP server runs on localhost:8000 to avoid browser security restrictions"
echo "   • Server will continue running until you stop it (Ctrl+C)"
echo "   • All files are served locally from your machine"
