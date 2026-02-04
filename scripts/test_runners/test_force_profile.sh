#!/bin/bash
# Profile force calculation performance

echo "========================================================================="
echo "FORCE CALCULATION PROFILE TEST"
echo "========================================================================="
echo ""
echo "This will:"
echo "  1. Boot the visual test"
echo "  2. Skip the benchmark (too slow)"
echo "  3. Run for ~10 seconds with profiling enabled"
echo "  4. Report force calculation timing"
echo ""
echo "Note: Press ESC to exit early if needed"
echo "========================================================================="
echo ""

cd /home/tehcr33d/ws/SpaceWheat

# Run with 15 second timeout
timeout 20 godot VisualBubbleTest.tscn 2>&1 | grep -E "PROFILING|PROFILE|force|Average|WARNING|CAUTION|Backend|frame budget" --line-buffered
