#!/bin/bash
# Launch SpaceWheat with software rendering (WSL2 workaround)
# The Intel D3D12 driver in WSL2 crashes - use Mesa software rasterizer instead

export LIBGL_ALWAYS_SOFTWARE=1

# Run Godot with all arguments passed through
godot "$@"
