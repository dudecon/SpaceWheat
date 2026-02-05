#!/bin/bash
# Download pre-built native C++ extensions from GitHub Releases
#
# Usage:
#   ./scripts/download_binaries.sh          # Download latest release
#   ./scripts/download_binaries.sh v0.1.0   # Download specific version
#
# This downloads and extracts the native extension for your platform,
# giving you 10-100x performance boost over GDScript fallback.

set -e

REPO="AQuantumArchitect/SpaceWheat"
VERSION="${1:-latest}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Detect platform
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$os" in
        linux*)  echo "linux" ;;
        darwin*) echo "macos" ;;
        mingw*|msys*|cygwin*) echo "windows" ;;
        *)
            echo "Unknown platform: $os" >&2
            exit 1
            ;;
    esac
}

PLATFORM=$(detect_platform)
echo "Detected platform: $PLATFORM"

# Determine archive name
case "$PLATFORM" in
    linux)   ARCHIVE="spacewheat-native-linux-x86_64.tar.gz" ;;
    windows) ARCHIVE="spacewheat-native-windows-x86_64.zip" ;;
    macos)   ARCHIVE="spacewheat-native-macos-universal.tar.gz" ;;
esac

# Get download URL
if [ "$VERSION" = "latest" ]; then
    echo "Fetching latest release..."
    DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$ARCHIVE"
else
    echo "Fetching release $VERSION..."
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/$ARCHIVE"
fi

# Create target directory
TARGET_DIR="$PROJECT_DIR/native/bin/$PLATFORM"
mkdir -p "$TARGET_DIR"

# Download
echo "Downloading $ARCHIVE..."
TEMP_FILE=$(mktemp)
if command -v curl &> /dev/null; then
    curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O "$TEMP_FILE" "$DOWNLOAD_URL"
else
    echo "Error: Neither curl nor wget found." >&2
    exit 1
fi

# Extract
echo "Extracting to $TARGET_DIR..."
case "$ARCHIVE" in
    *.tar.gz) tar xzf "$TEMP_FILE" -C "$TARGET_DIR" ;;
    *.zip)    unzip -o "$TEMP_FILE" -d "$TARGET_DIR" ;;
esac

# Clean up
rm -f "$TEMP_FILE"

# Verify
echo ""
echo "Installed native extension:"
ls -lh "$TARGET_DIR/"
echo ""
echo "Done! Native C++ acceleration is ready."
echo ""
echo "NOTE: Make sure your platform is uncommented in quantum_matrix.gdextension"
echo "  Look for lines starting with '$PLATFORM' and remove the '#' comment marker."
