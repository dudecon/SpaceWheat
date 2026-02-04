#!/bin/bash
# Prepare source tarball for Google Colab build

set -e

cd ~/ws/SpaceWheat

echo "Creating source tarball for Google Colab..."
echo ""

# Create temporary directory
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/native"

# Copy native source
echo "Copying native source..."
cp -r native/src "$TMPDIR/native/"
cp -r native/include "$TMPDIR/native/"
cp native/SConstruct "$TMPDIR/native/"

# Copy godot-cpp (required for build)
echo "Copying godot-cpp..."
cp -r ../godot-cpp "$TMPDIR/"

# Create tarball
echo "Creating tarball..."
cd "$TMPDIR"
tar -czf native_source.tar.gz native/ godot-cpp/

# Move to native directory
mv native_source.tar.gz ~/ws/SpaceWheat/native/

# Cleanup
rm -rf "$TMPDIR"

cd ~/ws/SpaceWheat/native
ls -lh native_source.tar.gz

echo ""
echo "✓ Tarball created: ~/ws/SpaceWheat/native/native_source.tar.gz"
echo ""
echo "Next steps:"
echo "1. Open colab_build.ipynb in Google Colab"
echo "2. Upload native_source.tar.gz"
echo "3. Run all cells"
echo "4. Download the compiled .so file"
echo "5. Place it in ~/ws/SpaceWheat/native/bin/"
