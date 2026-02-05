#!/bin/bash
# Launch VisualBubbleTest scene for WSL2 development
# Uses same WSLg-compatible settings as dev_launch.sh

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0

# Force software compositing so WSLg's Weston can actually present frames
export LIBGL_ALWAYS_SOFTWARE=1

# Run the test scene
godot --rendering-driver opengl3 --rendering-method gl_compatibility VisualBubbleTest.tscn
