#!/bin/bash
# Development launcher for WSL2
# Forces OpenGL (works with D3D12 hardware GPU in WSL2)
# Production Windows builds will use Vulkan mobile mode from project.godot

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0

# Force OpenGL3 renderer for WSL2 development
# (project.godot is configured for Vulkan mobile for Windows builds)
# Using explicit window flags for better WSLg compatibility
godot --rendering-driver opengl3 --path . --resolution 960x540 --position 100,100 "$@"
