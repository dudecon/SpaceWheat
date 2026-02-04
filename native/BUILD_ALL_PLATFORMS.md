# Building Native Extension for All Platforms

**CRITICAL:** GDScript fallback is 4000× slower - native builds are REQUIRED for all platforms.

---

## Automated Builds (GitHub Actions) - RECOMMENDED

### Setup

1. **Add godot-cpp as submodule:**
```bash
cd ~/ws/SpaceWheat
git submodule add https://github.com/godotengine/godot-cpp
git submodule update --init --recursive
```

2. **Commit the workflow:**
```bash
git add .github/workflows/build-gdextension.yml
git commit -m "Add cross-platform build workflow"
git push
```

3. **GitHub builds automatically:**
- Every push to main/develop
- Every pull request
- Manual trigger via Actions tab

4. **Download builds:**
- Go to Actions tab
- Click latest workflow run
- Download "all-platforms" artifact
- Extract to `native/bin/`

---

## Manual Builds Per Platform

### Linux (You Have This)

```bash
cd ~/ws/SpaceWheat/native
make -j$(nproc)
```

---

### Windows (Cross-Compile from Linux)

**Install MinGW:**
```bash
sudo apt-get install mingw-w64 g++-mingw-w64-x86-64
```

**Build godot-cpp for Windows:**
```bash
cd ~/ws/godot-cpp
scons platform=windows target=template_release -j$(nproc)
```

**Create Windows Makefile:**
```bash
cat > ~/ws/SpaceWheat/native/Makefile.windows << 'EOF'
CXX = x86_64-w64-mingw32-g++
CXXFLAGS = -std=c++17 -O2 -DWINDOWS_ENABLED -DGDEXTENSION \
           -I./include -I./include/godot_cpp -I./include/gdextension

LDFLAGS = -shared -static-libgcc -static-libstdc++ \
          ../godot-cpp/bin/libgodot-cpp.windows.template_release.x86_64.a

SOURCES = $(wildcard src/*.cpp)
OBJECTS = $(SOURCES:.cpp=.obj)
TARGET = bin/libquantummatrix.windows.template_release.x86_64.dll

all: bin $(TARGET)
	@cd bin && ln -sf libquantummatrix.windows.template_release.x86_64.dll \
	                  libquantummatrix.windows.template_debug.x86_64.dll

bin:
	mkdir -p bin

$(TARGET): $(OBJECTS)
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)

%.obj: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f src/*.obj bin/*.dll

.PHONY: all clean
EOF
```

**Build:**
```bash
cd ~/ws/SpaceWheat/native
make -f Makefile.windows -j$(nproc)
```

---

### macOS (Cross-Compile - Advanced)

**Requires OSX Cross toolchain:**
```bash
# Install osxcross (takes ~1 hour, requires macOS SDK)
git clone https://github.com/tpoechtrager/osxcross
cd osxcross
# Follow instructions to install SDK
```

**OR use GitHub Actions** (much easier)

---

### Web (WASM)

**Install Emscripten:**
```bash
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

**Build godot-cpp for web:**
```bash
cd ~/ws/godot-cpp
source ~/emsdk/emsdk_env.sh
scons platform=web target=template_release -j$(nproc)
```

**Create Web Makefile:**
```bash
cat > ~/ws/SpaceWheat/native/Makefile.web << 'EOF'
CXX = emcc
CXXFLAGS = -std=c++17 -O3 -s SIDE_MODULE=1 -s EXPORT_ALL=1 \
           -DWEB_ENABLED -DGDEXTENSION \
           -I./include -I./include/godot_cpp -I./include/gdextension

SOURCES = $(wildcard src/*.cpp)
TARGET = bin/libquantummatrix.wasm

all: bin $(TARGET)

bin:
	mkdir -p bin

$(TARGET): $(SOURCES)
	$(CXX) $(CXXFLAGS) $(SOURCES) -o $@

clean:
	rm -f bin/*.wasm

.PHONY: all clean
EOF
```

**Build:**
```bash
cd ~/ws/SpaceWheat/native
source ~/emsdk/emsdk_env.sh
make -f Makefile.web
```

**IMPORTANT: Test WASM build with Eigen!**
Eigen might have issues in WASM. Test thoroughly.

---

## Using Pre-Built godot-cpp

**To save time, build godot-cpp ONCE for each platform:**

```bash
# Linux
cd ~/ws/godot-cpp
scons platform=linux target=template_release -j$(nproc)
cp bin/libgodot-cpp.linux.template_release.x86_64.a ~/ws/SpaceWheat/native/lib/

# Windows (with MinGW)
scons platform=windows target=template_release -j$(nproc)
cp bin/libgodot-cpp.windows.template_release.x86_64.a ~/ws/SpaceWheat/native/lib/

# Web (with Emscripten)
source ~/emsdk/emsdk_env.sh
scons platform=web target=template_release -j$(nproc)
cp bin/libgodot-cpp.web.template_release.wasm32.a ~/ws/SpaceWheat/native/lib/
```

Then you can build your extension quickly without rebuilding godot-cpp.

---

## Update .gdextension File

**Uncomment all platforms:**
```ini
[configuration]
entry_symbol = "quantum_matrix_library_init"
compatibility_minimum = "4.1"

[libraries]

linux.debug.x86_64 = "res://native/bin/libquantummatrix.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://native/bin/libquantummatrix.linux.template_release.x86_64.so"

windows.debug.x86_64 = "res://native/bin/libquantummatrix.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://native/bin/libquantummatrix.windows.template_release.x86_64.dll"

web.wasm32 = "res://native/bin/libquantummatrix.wasm"

macos.debug = "res://native/bin/libquantummatrix.macos.template_debug.framework"
macos.release = "res://native/bin/libquantummatrix.macos.template_release.framework"
```

---

## Testing Each Platform

### Windows (with Wine)
```bash
# Export Windows build
godot --headless --export-release "Windows Desktop" build/SpaceWheat.exe

# Test with Wine
wine build/SpaceWheat.exe
```

### Web
```bash
# Export web build
godot --headless --export-release "Web" build/web/index.html

# Test locally
python3 -m http.server -d build/web 8000
# Visit http://localhost:8000
```

**Check console for:**
- ✅ "Native acceleration enabled"
- ❌ "Using GDScript fallback" (means WASM didn't load)

---

## Build Time Estimates

| Platform | First Build | Incremental |
|----------|-------------|-------------|
| Linux | 60 sec | 5-10 sec |
| Windows (cross) | 90 sec | 10-15 sec |
| macOS (cross) | 120 sec | 15-20 sec |
| Web (WASM) | 120 sec | 15-20 sec |

**With GitHub Actions:** All platforms in ~10-15 minutes (parallel builds)

---

## Recommended Workflow

**For Development:**
1. Develop on Linux (native build)
2. Test locally

**For Release:**
1. Push to GitHub
2. GitHub Actions builds all platforms
3. Download artifacts
4. Add to export templates
5. Export game for each platform

**For itch.io:**
1. Upload Windows build with .dll
2. Upload Linux build with .so
3. Upload Web build with .wasm (IF Eigen works)
4. OR don't ship web if WASM is problematic

---

## WASM Concerns

**Eigen in WASM might have issues:**
- Threading limitations
- SIMD support varies
- Matrix functions might fail

**Test thoroughly:**
```bash
# After building WASM
godot --headless --export-release "Web" test.html
python3 -m http.server

# Open browser console, look for:
# - Eigen errors
# - Performance (should be close to native, not 4000× slower)
# - Memory issues
```

**If WASM doesn't work:**
- Don't ship web version
- OR create simplified version without heavy Eigen operations

---

## Summary

**MUST HAVE native builds for:**
- ✅ Linux (you have this)
- ✅ Windows (cross-compile with MinGW OR GitHub Actions)
- ⚠️ Web (WASM - needs testing with Eigen)

**Easiest approach:** GitHub Actions (automated, free, builds all platforms)

**Manual approach:** Cross-compile on Linux (Windows works, macOS hard, Web requires Emscripten)
