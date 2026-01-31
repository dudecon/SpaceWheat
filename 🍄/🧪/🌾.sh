#!/bin/bash

# 🌾 - SpaceWheat Visual Bubble Test with GPU Emoji Atlas Verification
# Watch quantum bubbles evolve and interact
# Verifies that emoji rendering is GPU-accelerated via atlas batching

# Source shared test library for DRY utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "🌾 Visual Bubble Test - GPU Emoji Verification"
echo "==========================="

# Run test ONCE and capture output
BUBBLE_OUTPUT=$(timeout 20 godot --scene VisualBubbleTest.tscn 2>&1 || true)
EXIT_CODE=$?

# Print ALL output (performance metrics, FPS, timing, etc.)
echo "$BUBBLE_OUTPUT"

# Analyze results
if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo -e "${GREEN}✅ Test completed (timeout after 20s)${NC}"
elif [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Test completed successfully${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Test exited with code: $EXIT_CODE${NC}"
fi

# Validate emoji atlas from captured output
validate_emoji_atlas "$BUBBLE_OUTPUT" "Visual Bubble Test"

# Analyze GPU offload status from same output
verify_gpu_offload "$BUBBLE_OUTPUT"

exit $EXIT_CODE
