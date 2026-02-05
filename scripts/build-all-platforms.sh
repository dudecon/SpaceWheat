#!/bin/bash
# build-all-platforms.sh - Build SpaceWheat native extensions for Linux, Windows, and Web
#
# Usage:
#   ./scripts/build-all-platforms.sh                # Build all platforms
#   ./scripts/build-all-platforms.sh --clean        # Rebuild godot-cpp
#   ./scripts/build-all-platforms.sh --linux-only   # Build Linux only
#   ./scripts/build-all-platforms.sh --help         # Show help

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NATIVE_DIR="$PROJECT_DIR/native"
GODOT_CPP_DIR="$PROJECT_DIR/godot-cpp"

# Options
DO_CLEAN=false
LINUX_ONLY=false
WINDOWS_ONLY=false
WEB_ONLY=false

# Colors
log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

show_help() {
    cat << 'EOF'
SpaceWheat Multi-Platform Native Builder

Builds C++ extensions for Linux, Windows (MinGW cross-compile), and Web (Emscripten).

Usage:
  ./scripts/build-all-platforms.sh [OPTIONS]

Options:
  --clean         Rebuild godot-cpp for all platforms
  --linux-only    Build Linux extension only
  --windows-only  Build Windows extension only
  --web-only      Build Web (WASM) extension only
  --help          Show this help

Prerequisites:
  - MinGW:      sudo apt-get install mingw-w64
  - Emscripten: source ~/emsdk/emsdk_env.sh
  - SCons:      pip3 install scons

Examples:
  # Build all platforms
  ./scripts/build-all-platforms.sh

  # Rebuild godot-cpp and extensions
  ./scripts/build-all-platforms.sh --clean

  # Build just Windows
  ./scripts/build-all-platforms.sh --windows-only

  # Build Linux and Windows (skip Web)
  ./scripts/build-all-platforms.sh --linux-only --windows-only
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean) DO_CLEAN=true; shift ;;
        --linux-only) LINUX_ONLY=true; shift ;;
        --windows-only) WINDOWS_ONLY=true; shift ;;
        --web-only) WEB_ONLY=true; shift ;;
        --help) show_help; exit 0 ;;
        *) error "Unknown option: $1\nRun with --help for usage" ;;
    esac
done

# If no specific platform selected, build all
if [ "$LINUX_ONLY" = false ] && [ "$WINDOWS_ONLY" = false ] && [ "$WEB_ONLY" = false ]; then
    LINUX_ONLY=true
    WINDOWS_ONLY=true
    WEB_ONLY=true
fi

log "SpaceWheat Multi-Platform Native Builder"
echo ""
echo "  Build targets:"
echo "    Linux:   $LINUX_ONLY"
echo "    Windows: $WINDOWS_ONLY"
echo "    Web:     $WEB_ONLY"
echo "    Clean:   $DO_CLEAN"
echo ""

# Check prerequisites
log "Checking prerequisites..."

if [ "$LINUX_ONLY" = true ]; then
    command -v g++ >/dev/null 2>&1 || error "g++ not found. Run: sudo apt-get install build-essential"
fi

if [ "$WINDOWS_ONLY" = true ]; then
    command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1 || error "MinGW not found. Run: sudo apt-get install mingw-w64"
fi

if [ "$WEB_ONLY" = true ]; then
    command -v emcc >/dev/null 2>&1 || error "Emscripten not found. Run: source ~/emsdk/emsdk_env.sh"
fi

command -v scons >/dev/null 2>&1 || error "SCons not found. Run: pip3 install scons"

success "All prerequisites found"

# Clean godot-cpp if requested
if [ "$DO_CLEAN" = true ]; then
    log "Cleaning godot-cpp..."
    cd "$GODOT_CPP_DIR"
    rm -rf bin/
    success "godot-cpp cleaned"
fi

# Build godot-cpp for requested platforms
log "Building godot-cpp..."

cd "$GODOT_CPP_DIR"

if [ "$LINUX_ONLY" = true ]; then
    if [ ! -f "bin/libgodot-cpp.linux.template_release.x86_64.a" ] || [ "$DO_CLEAN" = true ]; then
        log "Building godot-cpp for Linux..."
        scons platform=linux target=template_release -j$(nproc)
        success "godot-cpp Linux built"
    else
        success "godot-cpp Linux already built (cached)"
    fi
fi

if [ "$WINDOWS_ONLY" = true ]; then
    if [ ! -f "bin/libgodot-cpp.windows.template_release.x86_64.a" ] || [ "$DO_CLEAN" = true ]; then
        log "Building godot-cpp for Windows..."
        scons platform=windows target=template_release -j$(nproc)
        success "godot-cpp Windows built"
    else
        success "godot-cpp Windows already built (cached)"
    fi
fi

if [ "$WEB_ONLY" = true ]; then
    if [ ! -f "bin/libgodot-cpp.web.template_release.wasm32.a" ] || [ "$DO_CLEAN" = true ]; then
        log "Building godot-cpp for Web..."
        # Ensure Emscripten is activated
        if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
            source "$HOME/emsdk/emsdk_env.sh"
        fi
        scons platform=web target=template_release -j$(nproc)
        success "godot-cpp Web built"
    else
        success "godot-cpp Web already built (cached)"
    fi
fi

# Build SpaceWheat extensions
cd "$NATIVE_DIR"

if [ "$LINUX_ONLY" = true ]; then
    log "Building Linux extension..."
    make clean >/dev/null 2>&1 || true
    make -j$(nproc)
    if [ -f "bin/linux/libquantummatrix.linux.template_release.x86_64.so" ]; then
        SIZE=$(ls -lh bin/linux/libquantummatrix.linux.template_release.x86_64.so | awk '{print $5}')
        success "Linux extension built ($SIZE)"
    else
        error "Linux build failed"
    fi
fi

if [ "$WINDOWS_ONLY" = true ]; then
    log "Building Windows extension..."
    mkdir -p bin/windows

    x86_64-w64-mingw32-g++ -std=c++17 -shared -O2 \
        -I./include \
        -I./include/godot_cpp \
        -I./include/gdextension \
        -DWINDOWS_ENABLED -DGDEXTENSION \
        src/*.cpp \
        ../godot-cpp/bin/libgodot-cpp.windows.template_release.x86_64.a \
        -o bin/windows/libquantummatrix.windows.template_release.x86_64.dll \
        -static-libgcc -static-libstdc++

    # Create debug symlink
    cd bin/windows
    ln -sf libquantummatrix.windows.template_release.x86_64.dll \
           libquantummatrix.windows.template_debug.x86_64.dll
    cd ../..

    if [ -f "bin/windows/libquantummatrix.windows.template_release.x86_64.dll" ]; then
        SIZE=$(ls -lh bin/windows/libquantummatrix.windows.template_release.x86_64.dll | awk '{print $5}')
        success "Windows extension built ($SIZE)"
    else
        error "Windows build failed"
    fi
fi

if [ "$WEB_ONLY" = true ]; then
    log "Building Web extension (WASM)..."
    mkdir -p bin/web

    # Ensure Emscripten is activated
    if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
        source "$HOME/emsdk/emsdk_env.sh"
    fi

    emcc -std=c++17 -O3 -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
        -I./include \
        -I./include/godot_cpp \
        -I./include/gdextension \
        -DWEB_ENABLED -DGDEXTENSION \
        src/*.cpp \
        -o bin/web/libquantummatrix.wasm

    if [ -f "bin/web/libquantummatrix.wasm" ]; then
        SIZE=$(ls -lh bin/web/libquantummatrix.wasm | awk '{print $5}')
        success "Web extension built ($SIZE)"
        warn "IMPORTANT: Test web build thoroughly - Eigen may have WASM compatibility issues"
    else
        error "Web build failed"
    fi
fi

# Summary
log "Build Summary:"
echo ""

if [ "$LINUX_ONLY" = true ] && [ -f "bin/linux/libquantummatrix.linux.template_release.x86_64.so" ]; then
    SIZE=$(ls -lh bin/linux/libquantummatrix.linux.template_release.x86_64.so | awk '{print $5}')
    echo "  ✅ Linux:   bin/linux/libquantummatrix.linux.template_release.x86_64.so ($SIZE)"
fi

if [ "$WINDOWS_ONLY" = true ] && [ -f "bin/windows/libquantummatrix.windows.template_release.x86_64.dll" ]; then
    SIZE=$(ls -lh bin/windows/libquantummatrix.windows.template_release.x86_64.dll | awk '{print $5}')
    echo "  ✅ Windows: bin/windows/libquantummatrix.windows.template_release.x86_64.dll ($SIZE)"
fi

if [ "$WEB_ONLY" = true ] && [ -f "bin/web/libquantummatrix.wasm" ]; then
    SIZE=$(ls -lh bin/web/libquantummatrix.wasm | awk '{print $5}')
    echo "  ✅ Web:     bin/web/libquantummatrix.wasm ($SIZE)"
fi

echo ""
success "All requested platforms built successfully!"
echo ""

if [ "$WINDOWS_ONLY" = true ] || [ "$WEB_ONLY" = true ]; then
    echo "Next steps:"
    echo "  1. Update quantum_matrix.gdextension (uncomment Windows/Web lines)"
    echo "  2. Export game for each platform:"
    if [ "$LINUX_ONLY" = true ]; then
        echo "     godot --headless --export-release \"Linux Desktop\" releases/linux/game.x86_64"
    fi
    if [ "$WINDOWS_ONLY" = true ]; then
        echo "     godot --headless --export-release \"Windows Desktop\" releases/windows/game.exe"
    fi
    if [ "$WEB_ONLY" = true ]; then
        echo "     godot --headless --export-release \"Web\" releases/web/index.html"
    fi
    echo "  3. Test builds:"
    if [ "$WINDOWS_ONLY" = true ]; then
        echo "     wine releases/windows/game.exe"
    fi
    if [ "$WEB_ONLY" = true ]; then
        echo "     python3 -m http.server -d releases/web 8000"
    fi
    echo ""
fi
