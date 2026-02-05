#!/bin/bash
# build-linux-release.sh - Build and package SpaceWheat Linux release
#
# Usage:
#   ./scripts/build-linux-release.sh                    # Build latest (v0.1.0)
#   ./scripts/build-linux-release.sh --version v0.2.0   # Build specific version
#   ./scripts/build-linux-release.sh --install          # Build + install to games folder
#   ./scripts/build-linux-release.sh --clean            # Force rebuild godot-cpp
#
# This script:
#   1. Clones fresh repo to build directory
#   2. Builds godot-cpp (cached unless --clean)
#   3. Builds C++ extension
#   4. Exports game via Godot headless
#   5. Creates tarball in releases/linux/
#   6. Optionally installs to ~/games/SpaceWheat/

set -e

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────
REPO_URL="git@github.com:AQuantumArchitect/SpaceWheat.git"
BUILD_DIR="$HOME/ws/tmp/SpaceWheat-build"
GODOT_CPP_CACHE="$HOME/ws/tmp/godot-cpp-cache"
RELEASE_DIR="$HOME/ws/SpaceWheat/releases/linux"
INSTALL_DIR="$HOME/games/SpaceWheat"
GODOT_BIN="${GODOT_BIN:-godot}"

# Defaults
VERSION="v0.1.0"
DO_INSTALL=false
DO_CLEAN=false
SKIP_CPP=false
SKIP_EXPORT=false
VERBOSE=false

# ─────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────
log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }
debug() { [ "$VERBOSE" = true ] && echo -e "\033[0;90m  $1\033[0m"; }

show_help() {
    cat << 'EOF'
SpaceWheat Linux Release Builder

USAGE:
    build-linux-release.sh [OPTIONS]

OPTIONS:
    --version, -v VERSION   Set release version (default: v0.1.0)
    --install, -i           Install to ~/games/SpaceWheat after build
    --clean, -c             Force rebuild of godot-cpp (normally cached)
    --skip-cpp              Skip C++ build (use existing binaries)
    --skip-export           Skip Godot export (use existing export)
    --verbose               Show detailed output
    --help, -h              Show this help message

EXAMPLES:
    # Basic build
    ./scripts/build-linux-release.sh

    # Build v0.2.0 and install
    ./scripts/build-linux-release.sh --version v0.2.0 --install

    # Quick rebuild (skip C++ if unchanged)
    ./scripts/build-linux-release.sh --skip-cpp --install

    # Full clean rebuild
    ./scripts/build-linux-release.sh --clean --install

ENVIRONMENT:
    GODOT_BIN       Path to Godot binary (default: godot)

OUTPUT:
    Tarball: ~/ws/SpaceWheat/releases/linux/spacewheat-linux-VERSION.tar.gz
    Install: ~/games/SpaceWheat/ (with --install)

EOF
    exit 0
}

# ─────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --install|-i)
            DO_INSTALL=true
            shift
            ;;
        --clean|-c)
            DO_CLEAN=true
            shift
            ;;
        --skip-cpp)
            SKIP_CPP=true
            shift
            ;;
        --skip-export)
            SKIP_EXPORT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            error "Unknown option: $1 (use --help for usage)"
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# Validate environment
# ─────────────────────────────────────────────────────────────
log "Validating environment..."

if ! command -v $GODOT_BIN &> /dev/null; then
    error "Godot not found. Set GODOT_BIN or ensure 'godot' is in PATH."
fi

if ! command -v scons &> /dev/null; then
    error "scons not found. Install with: pip install scons"
fi

if ! command -v g++ &> /dev/null; then
    error "g++ not found. Install build-essential."
fi

GODOT_VERSION=$($GODOT_BIN --version 2>/dev/null | head -1)
success "Environment OK (Godot: $GODOT_VERSION)"

echo ""
echo "  Version:     $VERSION"
echo "  Install:     $DO_INSTALL"
echo "  Clean:       $DO_CLEAN"
echo "  Skip C++:    $SKIP_CPP"
echo "  Skip Export: $SKIP_EXPORT"

# ─────────────────────────────────────────────────────────────
# Step 1: Clone fresh repo
# ─────────────────────────────────────────────────────────────
log "Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

git clone --recurse-submodules "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"

COMMIT_HASH=$(git rev-parse --short HEAD)
success "Cloned repo to $BUILD_DIR (commit: $COMMIT_HASH)"

# ─────────────────────────────────────────────────────────────
# Step 2: Build godot-cpp (with caching)
# ─────────────────────────────────────────────────────────────
GODOT_CPP_LIB="libgodot-cpp.linux.template_release.x86_64.a"

if [ "$DO_CLEAN" = true ]; then
    log "Cleaning godot-cpp cache (--clean)..."
    rm -rf "$GODOT_CPP_CACHE"
fi

mkdir -p "$GODOT_CPP_CACHE"

if [ -f "$GODOT_CPP_CACHE/$GODOT_CPP_LIB" ]; then
    log "Using cached godot-cpp..."
    mkdir -p "$BUILD_DIR/native/lib"
    cp "$GODOT_CPP_CACHE/$GODOT_CPP_LIB" "$BUILD_DIR/native/lib/"
    success "Copied cached godot-cpp library"
else
    log "Building godot-cpp (this takes ~5 minutes)..."
    cd "$BUILD_DIR/godot-cpp"
    scons platform=linux target=template_release -j$(nproc)

    # Cache it for next time
    cp "bin/$GODOT_CPP_LIB" "$GODOT_CPP_CACHE/"
    mkdir -p "$BUILD_DIR/native/lib"
    cp "bin/$GODOT_CPP_LIB" "$BUILD_DIR/native/lib/"
    success "godot-cpp built and cached"
fi

# ─────────────────────────────────────────────────────────────
# Step 3: Build C++ extension
# ─────────────────────────────────────────────────────────────
if [ "$SKIP_CPP" = true ]; then
    warn "Skipping C++ build (--skip-cpp)"
else
    log "Building C++ extension..."
    cd "$BUILD_DIR/native"
    make clean 2>/dev/null || true
    make -j$(nproc)

    SO_FILE=$(ls -1 bin/linux/*.so 2>/dev/null | grep -v debug | head -1)
    SO_SIZE=$(du -h "$SO_FILE" | cut -f1)
    success "C++ extension built: $SO_SIZE"
fi

# ─────────────────────────────────────────────────────────────
# Step 4: Export game with Godot
# ─────────────────────────────────────────────────────────────
EXPORT_DIR="$BUILD_DIR/export/SpaceWheat"

if [ "$SKIP_EXPORT" = true ]; then
    warn "Skipping Godot export (--skip-export)"
    if [ ! -d "$EXPORT_DIR" ]; then
        error "No existing export found. Remove --skip-export."
    fi
else
    log "Exporting game with Godot..."
    cd "$BUILD_DIR"
    mkdir -p "$EXPORT_DIR"

    # Import project first (generates .godot folder)
    debug "Importing project..."
    timeout 60 $GODOT_BIN --headless --import . 2>/dev/null || true

    # Export
    debug "Running export..."
    $GODOT_BIN --headless --export-release "Linux" "$EXPORT_DIR/SpaceWheat.x86_64"

    if [ ! -f "$EXPORT_DIR/SpaceWheat.x86_64" ]; then
        error "Export failed - SpaceWheat.x86_64 not created"
    fi

    success "Game exported"
fi

# Copy C++ extension to export
log "Packaging C++ extension with export..."
cp "$BUILD_DIR/native/bin/linux/"*.so "$EXPORT_DIR/" 2>/dev/null || warn "No .so files to copy"

# Add launch script if not present
if [ ! -f "$EXPORT_DIR/launch.sh" ]; then
    cat > "$EXPORT_DIR/launch.sh" << 'LAUNCH'
#!/bin/bash
cd "$(dirname "$0")"
./SpaceWheat.x86_64 "$@"
LAUNCH
    chmod +x "$EXPORT_DIR/launch.sh"
fi

# ─────────────────────────────────────────────────────────────
# Step 5: Create tarball
# ─────────────────────────────────────────────────────────────
log "Creating release tarball..."
mkdir -p "$RELEASE_DIR"
TARBALL="$RELEASE_DIR/spacewheat-linux-${VERSION}.tar.gz"

cd "$BUILD_DIR/export"
tar czf "$TARBALL" SpaceWheat/

TARBALL_SIZE=$(du -h "$TARBALL" | cut -f1)
success "Release created: $TARBALL ($TARBALL_SIZE)"

# ─────────────────────────────────────────────────────────────
# Step 6: Install (optional)
# ─────────────────────────────────────────────────────────────
if [ "$DO_INSTALL" = true ]; then
    log "Installing to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    tar xzf "$TARBALL" -C "$(dirname "$INSTALL_DIR")"

    # Verify
    if [ -f "$INSTALL_DIR/SpaceWheat.x86_64" ]; then
        success "Installed to $INSTALL_DIR"
    else
        error "Installation verification failed"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────
log "Cleaning up build directory..."
rm -rf "$BUILD_DIR"
success "Build directory cleaned"

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "\033[1;32m✓ SpaceWheat Linux $VERSION build complete!\033[0m"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Tarball:  $TARBALL"
echo "  Size:     $TARBALL_SIZE"
echo "  Commit:   $COMMIT_HASH"
echo ""

if [ "$DO_INSTALL" = true ]; then
    echo "  Installed: $INSTALL_DIR"
    echo ""
    echo "  Run with:"
    echo "    $INSTALL_DIR/SpaceWheat.x86_64"
    echo ""
fi

echo "  Upload to GitHub Releases:"
echo "    gh release create $VERSION $TARBALL --title \"SpaceWheat $VERSION\""
echo ""
echo "  Upload to itch.io (with butler):"
echo "    butler push $TARBALL yourname/spacewheat:linux"
echo ""
echo "════════════════════════════════════════════════════════════"
