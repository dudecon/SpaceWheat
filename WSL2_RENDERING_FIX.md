# WSL2 Rendering Crash Fix

## Problem

When running `godot` directly on WSL2, the game crashes with signal 11 in Intel GPU drivers:
```
[4] /usr/lib/wsl/drivers/iigd_dch.inf_amd64_51f685305808e3a5/libigd12dxva64.so
[14] /usr/lib/wsl/lib/libd3d12core.so
[24] /usr/lib/x86_64-linux-gnu/dri/swrast_dri.so
```

This is a known WSL2 + Godot 4.x compatibility issue with the D3D12 rendering backend.

## Solution

Use software rendering via Mesa's llvmpipe by setting `LIBGL_ALWAYS_SOFTWARE=1`.

### Usage

**Option 1: Use the provided script** (recommended)
```bash
./run_game.sh                        # Open Godot editor
./run_game.sh res://scenes/FarmView.tscn  # Run game directly
./run_game.sh --headless -s test.gd       # Run headless tests
```

**Option 2: Set environment variable manually**
```bash
export LIBGL_ALWAYS_SOFTWARE=1
godot  # or any godot command
```

**Option 3: Add to ~/.bashrc for permanent fix**
```bash
echo 'export LIBGL_ALWAYS_SOFTWARE=1' >> ~/.bashrc
source ~/.bashrc
```

## Performance

Software rendering (llvmpipe) is slower than hardware-accelerated rendering but:
- ✅ No crashes
- ✅ Fully functional for development/testing
- ✅ 2D games run at acceptable framerates
- ⚠️ 3D intensive games may be slower

For production deployment, use native Windows or Linux with proper GPU drivers.

## Technical Details

- **Root cause**: WSL2's Intel D3D12 driver crashes during initialization
- **Workaround**: Force OpenGL via Mesa software rasterizer
- **Renderer used**: `llvmpipe (LLVM 15.0.7, 256 bits)` - CPU-based OpenGL 4.5
- **Native code status**: All GPU-accelerated C++ code has been removed from compilation
- **GDScript code**: Already uses CPU-only algorithms with optional C++ acceleration for matrix operations

This issue is entirely separate from our quantum simulation code - it's a WSL2 + Godot rendering backend incompatibility.
