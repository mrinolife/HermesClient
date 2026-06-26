#!/bin/bash
# HermesClient Quick Start
# Sets up the project locally (Linux/WSL: just creates files)
# On macOS: generates Xcode project and opens

set -e

echo "📱 HermesClient Setup"
echo "====================="

# Check if we're on macOS
if [[ "$(uname)" == "Darwin" ]]; then
    echo "🍎 macOS detected"
    
    # Check for XcodeGen
    if ! command -v xcodegen &> /dev/null; then
        echo "Installing XcodeGen..."
        brew install xcodegen
    fi
    
    echo "Generating Xcode project..."
    cd "$(dirname "$0")/HermesClient"
    xcodegen generate
    
    echo "Opening Xcode..."
    open HermesClient.xcodeproj
    
    echo ""
    echo "✅ Project ready! Hit Cmd+R to build and run."
else
    echo "🐧 Linux/WSL detected — can't build iOS natively."
    echo ""
    echo "To build:"
    echo "  1. Push this repo to GitHub"
    echo "  2. GitHub Actions will build the .ipa"
    echo "  3. Download the artifact"
    echo "  4. Sideload with AltStore or SideStore"
    echo ""
    echo "Files created. Ready for git push."
fi
