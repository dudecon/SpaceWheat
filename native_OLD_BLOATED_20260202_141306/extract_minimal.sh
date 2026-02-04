#!/bin/bash
# Extract minimal buildable package (no 971-file bloat)

set -e

MINIMAL_DIR="$HOME/ws/SpaceWheat_minimal_native"

echo "=== Creating Minimal Standalone Build ==="
echo ""
echo "This will:"
echo "  - Extract your 7 .cpp files"
echo "  - Copy Eigen headers"
echo "  - Copy ONLY the godot-cpp files you actually use"
echo "  - Create a simple Makefile (no scons bloat)"
echo ""
echo "Result: Builds in ~30 seconds instead of 20+ minutes"
echo ""

rm -rf "$MINIMAL_DIR"
mkdir -p "$MINIMAL_DIR"/{src,include,lib}

echo "Copying your source files..."
cp ~/ws/SpaceWheat/native/src/*.cpp "$MINIMAL_DIR/src/"
cp ~/ws/SpaceWheat/native/src/*.h "$MINIMAL_DIR/src/" 2>/dev/null || true

echo "Copying Eigen (header-only)..."
cp -r ~/ws/SpaceWheat/native/include/Eigen "$MINIMAL_DIR/include/"

echo "Copying minimal godot-cpp..."
mkdir -p "$MINIMAL_DIR/include/godot_cpp"
# Copy only the headers you actually use
cp -r ~/ws/godot-cpp/include/godot_cpp/core "$MINIMAL_DIR/include/godot_cpp/"
cp -r ~/ws/godot-cpp/include/godot_cpp/variant "$MINIMAL_DIR/include/godot_cpp/"
cp -r ~/ws/godot-cpp/include/godot_cpp/classes "$MINIMAL_DIR/include/godot_cpp/" 2>/dev/null || true
cp -r ~/ws/godot-cpp/gdextension "$MINIMAL_DIR/include/"
cp ~/ws/godot-cpp/include/godot_cpp/godot.hpp "$MINIMAL_DIR/include/godot_cpp/"

echo "Copying pre-compiled godot-cpp library..."
cp ~/ws/godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a "$MINIMAL_DIR/lib/"

echo "Creating Makefile..."
cat > "$MINIMAL_DIR/Makefile" << 'EOF'
CXX = g++
CXXFLAGS = -std=c++17 -fPIC -O2 -march=x86-64 \
           -I./include \
           -I./include/godot_cpp \
           -I./include/gdextension \
           -DLINUX_ENABLED -DUNIX_ENABLED -DGDEXTENSION

LDFLAGS = -shared -L./lib -lgodot-cpp

SOURCES = $(wildcard src/*.cpp)
OBJECTS = $(SOURCES:.cpp=.o)
TARGET = libquantummatrix.linux.template_release.x86_64.so

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)
	@echo ""
	@echo "✓ Build complete: $(TARGET)"
	@ls -lh $(TARGET)

%.o: %.cpp
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f src/*.o $(TARGET)

.PHONY: all clean
EOF

echo ""
echo "✓ Minimal package created: $MINIMAL_DIR"
echo ""
echo "To build (30 seconds):"
echo "  cd $MINIMAL_DIR"
echo "  make -j$(nproc)"
echo ""
echo "Then copy:"
echo "  cp libquantummatrix.linux.template_release.x86_64.so \\"
echo "     ~/ws/SpaceWheat/native/bin/"
