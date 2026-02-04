#!/bin/bash
# Test the integrated compute benchmark system

echo "========================================================================="
echo "INTEGRATED COMPUTE BENCHMARK TEST"
echo "========================================================================="
echo ""
echo "This will:"
echo "  1. Boot the visual test"
echo "  2. Run GPU vs CPU benchmark (with 100 nodes, 10 iterations)"
echo "  3. Select the fastest backend"
echo "  4. Show results before starting visualization"
echo ""
echo "========================================================================="
echo ""

cd /home/tehcr33d/ws/SpaceWheat

export DISPLAY=:0
export MESA_LOADER_DRIVER_OVERRIDE=zink

# Run test and capture benchmark output
godot VisualBubbleTest.tscn 2>&1 | grep --line-buffered -E "BENCHMARK|ComputeSelector|GPU|CPU|Winner|Recommendation|iteration"
