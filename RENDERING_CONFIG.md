# Rendering Configuration

## Target Platform: Windows

**Production configuration** in `project.godot`:
```ini
[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile=RenderingDevice
```

This enables **Vulkan mobile mode** which will use hardware GPU when built for native Windows.

---

## Development Environment: WSL2

**WSL2 limitation:** Vulkan only exposes llvmpipe (software rendering), which hangs during initialization.

**Solution:** Use the development launcher script for WSL2:

```bash
# Run game in WSL2 (forces OpenGL + D3D12 hardware GPU)
./dev_launch.sh

# Run editor in WSL2
./dev_launch.sh -e
```

The dev launcher:
- Forces OpenGL3 renderer via `--rendering-driver opengl3`
- Uses hardware GPU via Mesa D3D12 backend (Intel HD 620)
- Sets up WSLg display environment
- Does NOT modify project.godot (Vulkan config stays for Windows builds)

---

## Rendering Backends

| Environment | Renderer | Backend | GPU |
|-------------|----------|---------|-----|
| **Windows build** | Vulkan Mobile | Native Vulkan | Hardware ✅ |
| **WSL2 dev** | OpenGL3 (forced) | Mesa D3D12 | Hardware ✅ |
| **WSL2 default** | Vulkan Mobile | llvmpipe | Software ❌ (hangs) |

---

## Building for Windows

When building for Windows from WSL2, the project.godot Vulkan config will be used automatically:

```bash
# Export to Windows (uses Vulkan mobile config from project.godot)
godot --headless --export-release "Windows Desktop" SpaceWheat.exe
```

The resulting Windows build will use **native Vulkan with hardware GPU acceleration**.

---

## C++ Native Extensions

Rendering is done in **GDScript only** (as of migration 2025-02-02):
- `Core/Visualization/BatchedBubbleRenderer.gd`
- `Core/Visualization/GeometryBatcher.gd`
- `Core/Visualization/EmojiAtlasBatcher.gd`

C++ extensions handle only:
- Quantum evolution (Lindblad solver)
- Matrix operations (Eigen)
- Lookahead engine
- Force graph physics

No C++ rendering code exists.
