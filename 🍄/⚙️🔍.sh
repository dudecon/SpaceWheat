#!/bin/bash

# ⚙️🔍 - Native Engine Status Check
# Quick diagnostic for GPU batching and C++ acceleration

cd "/home/tehcr33d/ws/SpaceWheat"

echo "⚙️ Native Engine Status Check"
echo "=============================="
echo "Checking which engines are loaded..."
echo ""

godot Tests/VisualBubbleStressTest.tscn
