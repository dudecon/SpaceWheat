# Cross-Platform Build Guide (Linux → Windows + Web)

This guide shows how to build SpaceWheat native extensions for **Linux, Windows, and Web** from a single Linux machine.

## Why Cross-Compile?

**GDScript fallback is 4000× slower** - native C++ extensions are REQUIRED for acceptable performance.

**Linux can build for:**
- ✅ Linux (native)
- ✅ Windows (MinGW cross-compiler)
- ✅ Web (Emscripten → WebAssembly)
- ❌ macOS (complex, requires Apple SDK - skipping)

---

## Prerequisites

### System Packages

```bash
# Update package manager
sudo apt-get update

# Core build tools
sudo apt-get install -y build-essential git python3-pip wget

# MinGW for Windows cross-compilation
sudo apt-get install -y mingw-w64 g++-mingw-w64-x86-64

# Scons build system
pip3 install scons

# Verify installations
x86_64-w64-mingw32-g++ --version  # Should show MinGW version
scons --version                    # Should show SCons version
```

### Emscripten (for Web builds)

```bash
# Clone Emscripten SDK
cd ~
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Install and activate latest
./emsdk install latest
./emsdk activate latest

# Add to shell (add this to ~/.bashrc for persistence)
source ~/emsdk/emsdk_env.sh

# Verify
emcc --version  # Should show Emscripten version
```

### Godot 4.5

```bash
# Download Godot headless
cd /tmp
wget https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip
unzip Godot_v4.5-stable_linux.x86_64.zip
sudo mv Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot
sudo chmod +x /usr/local/bin/godot

godot --version  # Should show: 4.5.stable.official.876b29033
```

---

## One-Time Setup: Build godot-cpp for All Platforms

This takes ~20-30 minutes but only needs to be done once (or when godot-cpp updates).

```bash
cd ~/SpaceWheat/godot-cpp

# Linux (5-10 min)
scons platform=linux target=template_release -j$(nproc)

# Windows (5-10 min)
scons platform=windows target=template_release -j$(nproc)

# Web (10-15 min) - requires Emscripten
source ~/emsdk/emsdk_env.sh
scons platform=web target=template_release -j$(nproc)

# Verify builds
ls -lh bin/
# Should see:
# - libgodot-cpp.linux.template_release.x86_64.a
# - libgodot-cpp.windows.template_release.x86_64.a
# - libgodot-cpp.web.template_release.wasm32.a
```

**Cache these libraries** (optional but recommended):
```bash
mkdir -p ~/godot-cpp-cache
cp godot-cpp/bin/*.a ~/godot-cpp-cache/
# Copy back later: cp ~/godot-cpp-cache/*.a godot-cpp/bin/
```

---

## Building SpaceWheat Extensions

### Linux Build (Native)

```bash
cd ~/SpaceWheat/native
make clean
make -j$(nproc)

# Verify
ls -lh bin/linux/libquantummatrix.linux.template_release.x86_64.so
# Should be ~1.7MB
```

### Windows Build (Cross-Compile)

```bash
cd ~/SpaceWheat/native

# Cross-compile with MinGW
x86_64-w64-mingw32-g++ -std=c++17 -shared -O2 \
  -I./include \
  -I./include/godot_cpp \
  -I./include/gdextension \
  -DWINDOWS_ENABLED -DGDEXTENSION \
  src/*.cpp \
  ../godot-cpp/bin/libgodot-cpp.windows.template_release.x86_64.a \
  -o bin/windows/libquantummatrix.windows.template_release.x86_64.dll \
  -static-libgcc -static-libstdc++

# Verify
ls -lh bin/windows/libquantummatrix.windows.template_release.x86_64.dll
# Should be ~1.5-2MB

# Create debug symlink (optional)
cd bin/windows
ln -sf libquantummatrix.windows.template_release.x86_64.dll \
       libquantummatrix.windows.template_debug.x86_64.dll
```

### Web Build (Emscripten → WASM)

```bash
cd ~/SpaceWheat/native

# Activate Emscripten
source ~/emsdk/emsdk_env.sh

# Compile to WebAssembly
mkdir -p bin/web
emcc -std=c++17 -O3 -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
  -I./include \
  -I./include/godot_cpp \
  -I./include/gdextension \
  -DWEB_ENABLED -DGDEXTENSION \
  src/*.cpp \
  -o bin/web/libquantummatrix.wasm

# Verify
ls -lh bin/web/libquantummatrix.wasm
# Should be ~500KB-1MB
```

**IMPORTANT - Web Build Testing:**
The Eigen library might have issues in WebAssembly. You MUST test the web build thoroughly:
```bash
godot --headless --export-release "Web" /tmp/test-web/index.html
cd /tmp/test-web
python3 -m http.server 8000
# Open browser to http://localhost:8000
# Check browser console for:
#   ✅ "Native acceleration enabled" (good!)
#   ❌ Errors about matrix operations (Eigen issues)
```

If WASM build has errors, comment out web entry in quantum_matrix.gdextension (GDScript fallback).

---

## Automated Build Script

I'll create a script that builds all three platforms automatically.

### Create `scripts/build-all-platforms.sh`

```bash
#!/bin/bash
# Build SpaceWheat native extensions for Linux, Windows, and Web

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NATIVE_DIR="$PROJECT_DIR/native"
GODOT_CPP_DIR="$PROJECT_DIR/godot-cpp"

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

# Check prerequisites
log "Checking prerequisites..."

command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1 || error "MinGW not found. Run: sudo apt-get install mingw-w64"
command -v emcc >/dev/null 2>&1 || error "Emscripten not found. Run: source ~/emsdk/emsdk_env.sh"
command -v scons >/dev/null 2>&1 || error "SCons not found. Run: pip3 install scons"

success "All prerequisites found"

# Build godot-cpp for all platforms (if not already built)
if [ ! -f "$GODOT_CPP_DIR/bin/libgodot-cpp.linux.template_release.x86_64.a" ] || \
   [ ! -f "$GODOT_CPP_DIR/bin/libgodot-cpp.windows.template_release.x86_64.a" ] || \
   [ ! -f "$GODOT_CPP_DIR/bin/libgodot-cpp.web.template_release.wasm32.a" ]; then
    log "Building godot-cpp for all platforms (this takes ~20 min)..."

    cd "$GODOT_CPP_DIR"

    log "Building godot-cpp for Linux..."
    scons platform=linux target=template_release -j$(nproc)

    log "Building godot-cpp for Windows..."
    scons platform=windows target=template_release -j$(nproc)

    log "Building godot-cpp for Web..."
    source ~/emsdk/emsdk_env.sh
    scons platform=web target=template_release -j$(nproc)

    success "godot-cpp built for all platforms"
else
    success "godot-cpp already built (using cached)"
fi

# Build Linux extension
log "Building Linux extension..."
cd "$NATIVE_DIR"
make clean
make -j$(nproc)
success "Linux build complete: $(ls -lh bin/linux/*.so | awk '{print $5}')"

# Build Windows extension
log "Building Windows extension..."
mkdir -p bin/windows
x86_64-w64-mingw32-g++ -std=c++17 -shared -O2 \
  -I./include -I./include/godot_cpp -I./include/gdextension \
  -DWINDOWS_ENABLED -DGDEXTENSION \
  src/*.cpp \
  ../godot-cpp/bin/libgodot-cpp.windows.template_release.x86_64.a \
  -o bin/windows/libquantummatrix.windows.template_release.x86_64.dll \
  -static-libgcc -static-libstdc++

cd bin/windows
ln -sf libquantummatrix.windows.template_release.x86_64.dll \
       libquantummatrix.windows.template_debug.x86_64.dll
cd ../..

success "Windows build complete: $(ls -lh bin/windows/*.dll | head -1 | awk '{print $5}')"

# Build Web extension
log "Building Web extension (WASM)..."
mkdir -p bin/web
source ~/emsdk/emsdk_env.sh
emcc -std=c++17 -O3 -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
  -I./include -I./include/godot_cpp -I./include/gdextension \
  -DWEB_ENABLED -DGDEXTENSION \
  src/*.cpp \
  -o bin/web/libquantummatrix.wasm

success "Web build complete: $(ls -lh bin/web/*.wasm | awk '{print $5}')"

# Summary
log "Build Summary:"
echo ""
echo "  Linux:   $(ls -lh bin/linux/*.so | awk '{print $9, $5}')"
echo "  Windows: $(ls -lh bin/windows/*.dll | grep -v debug | awk '{print $9, $5}')"
echo "  Web:     $(ls -lh bin/web/*.wasm | awk '{print $9, $5}')"
echo ""
success "All platforms built successfully!"
echo ""
echo "Next steps:"
echo "  1. Update quantum_matrix.gdextension (uncomment Windows and Web)"
echo "  2. Export game for each platform with Godot"
echo "  3. Test web build thoroughly (Eigen compatibility)"
```

Make it executable:
```bash
chmod +x ~/SpaceWheat/scripts/build-all-platforms.sh
```

---

## Enable All Platforms in quantum_matrix.gdextension

Edit `quantum_matrix.gdextension`:

```ini
[configuration]
entry_symbol = "quantum_matrix_library_init"
compatibility_minimum = "4.1"

[libraries]

# Linux (native)
linux.x86_64 = "res://native/bin/linux/libquantummatrix.linux.template_release.x86_64.so"
linux.debug.x86_64 = "res://native/bin/linux/libquantummatrix.linux.template_release.x86_64.so"
linux.release.x86_64 = "res://native/bin/linux/libquantummatrix.linux.template_release.x86_64.so"

# Windows (cross-compiled from Linux)
windows.x86_64 = "res://native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll"
windows.debug.x86_64 = "res://native/bin/windows/libquantummatrix.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://native/bin/windows/libquantummatrix.windows.template_release.x86_64.dll"

# Web (Emscripten → WASM)
web.wasm32 = "res://native/bin/web/libquantummatrix.wasm"

# macOS - SKIPPED (not building for Mac)
```

---

## Export Game for Each Platform

### Export Presets Setup

In Godot editor or export_presets.cfg, ensure you have:
- Linux/X11
- Windows Desktop
- Web

### Export Commands

```bash
cd ~/SpaceWheat

# Linux
mkdir -p releases/linux
godot --headless --export-release "Linux Desktop" \
  releases/linux/spacewheat-linux.x86_64

# Windows
mkdir -p releases/windows
godot --headless --export-release "Windows Desktop" \
  releases/windows/spacewheat-windows.exe

# Web
mkdir -p releases/web
godot --headless --export-release "Web" \
  releases/web/index.html
```

### Package Releases

```bash
# Linux tarball
cd releases/linux
tar -czf ../spacewheat-linux-v0.1.0.tar.gz .
cd ..

# Windows zip
cd windows
zip -r ../spacewheat-windows-v0.1.0.zip .
cd ..

# Web (already ready - upload entire web/ folder to itch.io)
```

---

## Testing

### Test Windows Build (with Wine)

```bash
sudo apt-get install wine64

cd ~/SpaceWheat/releases/windows
wine spacewheat-windows.exe

# Should launch game with native C++ acceleration
```

### Test Web Build

```bash
cd ~/SpaceWheat/releases/web
python3 -m http.server 8000

# Open browser to http://localhost:8000
# Open browser console (F12)
# Look for:
#   ✅ "Loading native extension: libquantummatrix.wasm"
#   ✅ Game runs smoothly
#   ❌ Errors about matrix operations (Eigen issue)
```

**If web build fails:**
Comment out web entry in quantum_matrix.gdextension and use GDScript fallback for web.

---

## Complete Workflow Summary

```bash
# 1. One-time VM setup (30 min)
sudo apt-get install mingw-w64 build-essential
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk && ./emsdk install latest && ./emsdk activate latest
source ~/emsdk/emsdk_env.sh  # Add to ~/.bashrc

# 2. Clone project
cd ~
git clone --recursive git@github.com:AQuantumArchitect/SpaceWheat.git
cd SpaceWheat

# 3. Build godot-cpp for all platforms (20 min, one-time)
cd godot-cpp
scons platform=linux target=template_release -j$(nproc)
scons platform=windows target=template_release -j$(nproc)
source ~/emsdk/emsdk_env.sh
scons platform=web target=template_release -j$(nproc)
cd ..

# 4. Build all native extensions (2 min)
./scripts/build-all-platforms.sh

# 5. Update quantum_matrix.gdextension (uncomment Windows and Web)
nano quantum_matrix.gdextension

# 6. Export for all platforms
godot --headless --export-release "Linux Desktop" releases/linux/game.x86_64
godot --headless --export-release "Windows Desktop" releases/windows/game.exe
godot --headless --export-release "Web" releases/web/index.html

# 7. Test
wine releases/windows/game.exe  # Test Windows
python3 -m http.server -d releases/web 8000  # Test Web

# 8. Package and upload to itch.io
```

---

## Troubleshooting

### "mingw not found"
```bash
sudo apt-get install mingw-w64 g++-mingw-w64-x86-64
x86_64-w64-mingw32-g++ --version
```

### "emcc not found"
```bash
source ~/emsdk/emsdk_env.sh
# Add to ~/.bashrc to persist:
echo 'source ~/emsdk/emsdk_env.sh' >> ~/.bashrc
```

### Windows build crashes
Test with Wine:
```bash
wine releases/windows/game.exe
# Check Wine console for errors
```

### Web build errors in browser console
WASM + Eigen might be incompatible. Comment out web entry in quantum_matrix.gdextension:
```ini
# web.wasm32 = "res://native/bin/web/libquantummatrix.wasm"
```

Game will use GDScript fallback (slower but functional).

---

## Performance Expectations

| Platform | Build Type | Performance | File Size |
|----------|-----------|-------------|-----------|
| Linux | Native .so | 100% | ~1.7MB |
| Windows | Cross-compile .dll | 100% | ~1.5MB |
| Web | WASM | 90-100% (if Eigen works) | ~800KB |

**All platforms should be 4000× faster than GDScript fallback.**
