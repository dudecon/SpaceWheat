#!/bin/bash

# 🔨🔧 - Rebuild Native Library
# Recompiles C++ extensions (quantum evolution, bubble renderer, etc.)

cd "/home/tehcr33d/ws/SpaceWheat/native"

echo "🔨 Rebuilding Native Library"
echo "============================="
echo "This will recompile all C++ engines..."
echo ""

scons -j4

echo ""
echo "✅ Build complete! Run ⚙️🔍.sh to verify engines loaded."
