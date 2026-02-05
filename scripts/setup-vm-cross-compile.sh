#!/bin/bash
# setup-vm-cross-compile.sh - One-time setup for cross-platform builds on Linux VM
#
# This installs MinGW (Windows cross-compiler) and Emscripten (Web/WASM compiler)
#
# Usage:
#   ./scripts/setup-vm-cross-compile.sh

set -e

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

log "SpaceWheat VM Cross-Compile Setup"
echo ""
echo "This will install:"
echo "  - MinGW (Windows cross-compiler)"
echo "  - Emscripten (WebAssembly compiler)"
echo "  - SCons (build system)"
echo "  - Godot 4.5 (if not already installed)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Update package manager
log "Updating package manager..."
sudo apt-get update

# Install core build tools
log "Installing build essentials..."
sudo apt-get install -y build-essential git python3-pip wget unzip

# Install MinGW for Windows cross-compilation
log "Installing MinGW (Windows cross-compiler)..."
sudo apt-get install -y mingw-w64 g++-mingw-w64-x86-64
success "MinGW installed: $(x86_64-w64-mingw32-g++ --version | head -1)"

# Install SCons
log "Installing SCons..."
pip3 install --user scons
success "SCons installed: $(scons --version | head -1)"

# Add pip user install to PATH if needed
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.local/bin:$PATH"
    success "Added ~/.local/bin to PATH (reload shell to persist)"
fi

# Install Emscripten
log "Installing Emscripten (this takes ~5 minutes)..."
if [ -d "$HOME/emsdk" ]; then
    success "Emscripten already installed at ~/emsdk"
else
    cd ~
    git clone https://github.com/emscripten-core/emsdk.git
    cd emsdk
    ./emsdk install latest
    ./emsdk activate latest
    success "Emscripten installed to ~/emsdk"
fi

# Add Emscripten to shell
if ! grep -q "emsdk_env.sh" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Emscripten SDK" >> ~/.bashrc
    echo "if [ -f ~/emsdk/emsdk_env.sh ]; then" >> ~/.bashrc
    echo "    source ~/emsdk/emsdk_env.sh >/dev/null 2>&1" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    success "Added Emscripten to ~/.bashrc (reload shell to persist)"
fi

# Activate Emscripten for current session
source ~/emsdk/emsdk_env.sh
success "Emscripten activated: $(emcc --version | head -1)"

# Install Godot if not already present
if command -v godot >/dev/null 2>&1; then
    success "Godot already installed: $(godot --version)"
else
    log "Installing Godot 4.5..."
    cd /tmp
    wget -q https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip
    unzip -q Godot_v4.5-stable_linux.x86_64.zip
    sudo mv Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot
    sudo chmod +x /usr/local/bin/godot
    rm Godot_v4.5-stable_linux.x86_64.zip
    success "Godot installed: $(godot --version)"
fi

# Optional: Install Wine for testing Windows builds
log "Installing Wine (for testing Windows builds)..."
if command -v wine >/dev/null 2>&1; then
    success "Wine already installed"
else
    sudo apt-get install -y wine64
    success "Wine installed: $(wine --version)"
fi

# Summary
log "Setup Complete!"
echo ""
echo "✅ Installed:"
echo "   - MinGW:      $(x86_64-w64-mingw32-g++ --version | head -1)"
echo "   - Emscripten: $(emcc --version | head -1)"
echo "   - SCons:      $(scons --version | head -1)"
echo "   - Godot:      $(godot --version)"
echo "   - Wine:       $(wine --version 2>/dev/null || echo 'not installed')"
echo ""
echo "⚠  Important: Reload your shell to activate Emscripten:"
echo "   source ~/.bashrc"
echo "   OR log out and log back in"
echo ""
echo "Next steps:"
echo "  1. Clone SpaceWheat:"
echo "     git clone --recursive git@github.com:AQuantumArchitect/SpaceWheat.git"
echo "     cd SpaceWheat"
echo ""
echo "  2. Build all platforms:"
echo "     ./scripts/build-all-platforms.sh"
echo ""
echo "  3. See BUILD_CROSS_PLATFORM.md for full documentation"
echo ""
