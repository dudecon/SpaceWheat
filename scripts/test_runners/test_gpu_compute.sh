#!/bin/bash
# Test pure GPU compute path with Zink (even if software Vulkan)

echo "========================================================================="
echo "GPU COMPUTE FORCE TEST - Pure Vulkan Path (C++ disabled)"
echo "========================================================================="
echo ""
echo "Configuration:"
echo "  - GPU compute: FORCED ON (even with llvmpipe)"
echo "  - C++ native: DISABLED"
echo "  - Fallback: GDScript only"
echo ""
echo "This will test how the force graph behaves when computed entirely on"
echo "the GPU (or software Vulkan emulation)."
echo ""
echo "========================================================================="
echo ""

# Set up Zink environment
export DISPLAY=:0
export MESA_LOADER_DRIVER_OVERRIDE=zink

# Optional verbose debugging
# export VK_LOADER_DEBUG=all

cd /home/tehcr33d/ws/SpaceWheat

echo "Starting Godot with Zink..."
echo ""
echo "WATCH FOR:"
echo "  ✅ 'GPUForceCalculator: Attempting GPU compute on llvmpipe'"
echo "  ✅ 'GPUForceCalculator: GPU acceleration ENABLED'"
echo "  ✅ 'QuantumForceSystem: GPU compute ENABLED'"
echo "  ❌ 'Native C++ engine ENABLED' (should be disabled)"
echo ""
echo "========================================================================="
echo ""

# Run and capture performance metrics
godot VisualBubbleTest.tscn 2>&1 | grep --line-buffered -E "GPU|Force|FPS|performance|llvmpipe|QuantumForce|Native"
