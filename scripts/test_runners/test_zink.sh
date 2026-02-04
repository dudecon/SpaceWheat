#!/bin/bash
# Test Zink GPU acceleration with Godot

echo "=== Testing Zink GPU Acceleration ==="
echo ""
echo "Setting MESA_LOADER_DRIVER_OVERRIDE=zink"
echo "This forces Mesa to translate Vulkan → OpenGL"
echo ""

export MESA_LOADER_DRIVER_OVERRIDE=zink

# Optional: Enable verbose Vulkan/Mesa debugging
# export VK_LOADER_DEBUG=all
# export MESA_DEBUG=1

echo "Launching Godot with Zink..."
echo "Watch for these messages in console:"
echo "  ✅ 'GPUForceCalculator: GPU acceleration ENABLED on <device>'"
echo "  ❌ 'GPUForceCalculator: Software Vulkan detected (llvmpipe)'"
echo ""

godot VisualBubbleTest.tscn 2>&1 | grep -E "GPU|Vulkan|RenderingDevice|QuantumForce" --line-buffered
