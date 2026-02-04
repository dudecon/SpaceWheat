#!/bin/bash
# Test Zink GPU compute in WSL2 with WSLg

echo "==================================================================="
echo "Testing Zink GPU Acceleration (WSL2 + WSLg)"
echo "==================================================================="
echo ""

# Set up environment
export DISPLAY=:0
export MESA_LOADER_DRIVER_OVERRIDE=zink

# Optional: Verbose debugging
# export VK_LOADER_DEBUG=all
# export MESA_DEBUG=1

echo "Environment:"
echo "  DISPLAY=$DISPLAY"
echo "  MESA_LOADER_DRIVER_OVERRIDE=$MESA_LOADER_DRIVER_OVERRIDE"
echo ""

echo "Looking for GPU info..."
lspci 2>/dev/null | grep -i vga || echo "lspci not available"
echo ""

echo "Launching Godot..."
echo "WATCH FOR:"
echo "  ✅ 'GPUForceCalculator: GPU acceleration ENABLED on <device>'"
echo "  ❌ 'GPUForceCalculator: Software Vulkan detected (llvmpipe)'"
echo "  ❌ 'GPUForceCalculator: Failed to create RenderingDevice'"
echo ""
echo "==================================================================="
echo ""

# Launch Godot and filter output
cd /home/tehcr33d/ws/SpaceWheat
godot VisualBubbleTest.tscn 2>&1 | grep --line-buffered -E "GPU|Vulkan|RenderingDevice|QuantumForce|llvmpipe|Intel|Zink|device_name"
