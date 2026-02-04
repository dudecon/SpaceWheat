#!/bin/bash
# Rebuild with minimal dependencies - NO RENDERING BLOAT

set -e

echo "=== SpaceWheat Native - Minimal Rebuild ==="
echo ""

# Kill existing builds
echo "Stopping existing builds..."
pkill -f "scons.*godot-cpp" 2>/dev/null || true
pkill -f "scons.*native" 2>/dev/null || true
sleep 2

cd ~/ws/SpaceWheat/native

# Clean everything
echo "Cleaning..."
scons -c -Q 2>&1 | tail -5
cd ~/ws/godot-cpp && scons -c -Q 2>&1 | tail -5
cd ~/ws/SpaceWheat/native

echo ""
echo "=== Problem Identified ==="
echo "godot-cpp is compiling 971 class bindings (rendering, UI, physics)"
echo "You only need ~10 classes (RefCounted, Dictionary, Array, etc.)"
echo ""
echo "Options:"
echo ""
echo "1. Continue with bloated build (971 files, ~20-30 min)"
echo "2. Create minimal godot-cpp (skip 960 unused files, ~2-3 min)"
echo "3. Use pre-compiled godot-cpp library (if available)"
echo ""
read -p "Choose option (1/2/3): " choice

case $choice in
  1)
    echo "Building with full godot-cpp..."
    cd ~/ws/godot-cpp && scons -j1
    cd ~/ws/SpaceWheat/native && scons -j1
    ;;
  2)
    echo "Minimal build requires godot-cpp source modification."
    echo "Not implemented yet - use option 1 for now."
    exit 1
    ;;
  3)
    echo "Checking for pre-compiled godot-cpp..."
    if [ -f ~/ws/godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a ]; then
      echo "✓ Found pre-compiled library, building extension only..."
      cd ~/ws/SpaceWheat/native && scons -j1
    else
      echo "✗ No pre-compiled library found."
      echo "Run full build once: cd ~/ws/godot-cpp && scons -j$(nproc)"
      exit 1
    fi
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo ""
echo "✓ Build complete!"
ls -lh bin/libquantummatrix*.so
