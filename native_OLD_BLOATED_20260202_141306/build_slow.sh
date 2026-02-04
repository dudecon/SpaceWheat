#!/bin/bash
# Single-threaded build for slow machines
cd ~/ws/SpaceWheat/native
echo "Building GDExtension (single-threaded, ~10-15 min)..."
scons -j1 2>&1 | tee build.log
echo ""
echo "Build complete! Check build.log for details."
ls -lh bin/libquantummatrix*.so
