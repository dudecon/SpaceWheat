#!/bin/bash
# Development launcher for WSL2
# Production Windows builds will use Vulkan mobile mode from project.godot

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0

# Force software compositing so WSLg's Weston can actually present frames
# D3D12 GPU driver renders off-screen but Weston can't composite the result
export LIBGL_ALWAYS_SOFTWARE=1

# Force OpenGL3 + gl_compatibility for WSL2
godot --rendering-driver opengl3 --rendering-method gl_compatibility --path . "$@"
