#!/bin/bash
# Launch Godot editor with OpenGL3 for WSL2 development
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir

godot --rendering-driver opengl3 -e
