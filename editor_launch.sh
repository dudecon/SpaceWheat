#!/bin/bash
# Launch Godot editor for WSL2 development

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0

# Force software compositing so WSLg's Weston can actually present frames
export LIBGL_ALWAYS_SOFTWARE=1

godot --rendering-driver opengl3 --rendering-method gl_compatibility -e
