#!/bin/bash
# Fast build using pre-compiled godot-cpp (81MB already built)

set -e

cd ~/ws/SpaceWheat/native

echo "=== Fast Build - Using Pre-Compiled godot-cpp ==="
echo ""

# Clean only our extension (not godot-cpp)
echo "Cleaning native extension..."
rm -rf bin/*.so bin/*.o 2>/dev/null || true

echo ""
echo "Building extension (7 files, ~1-2 min)..."
echo "Using existing: ~/ws/godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a"
echo ""

# Build for release (matches existing godot-cpp)
scons target=template_release -j$(nproc) 2>&1 | grep -E "Compiling|Linking|\.cpp|\.so|Error" || true

echo ""
if [ -f bin/libquantummatrix.linux.template_release.x86_64.so ]; then
  echo "✓ Build complete!"
  ls -lh bin/libquantummatrix.linux.template_release.x86_64.so
  echo ""
  echo "Next: Update .gdextension file to use template_release"
else
  echo "✗ Build failed - check output above"
  exit 1
fi
