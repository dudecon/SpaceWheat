#!/bin/bash
# Test threaded evolution - CPU should no longer block rendering

echo "========================================================================="
echo "THREADED EVOLUTION TEST"
echo "========================================================================="
echo ""
echo "Expected behavior:"
echo "  - C++ evolution runs on BACKGROUND thread"
echo "  - Main thread never blocks"
echo "  - Rendering stays smooth (20+ FPS)"
echo "  - Look for: 'Threaded evolution ENABLED'"
echo "  - Look for: '[threaded]' in batch logs"
echo ""
echo "========================================================================="
echo ""

cd /home/tehcr33d/ws/SpaceWheat

export DISPLAY=:0
export MESA_LOADER_DRIVER_OVERRIDE=zink

# Run and filter for threading-related output
timeout 25 godot VisualBubbleTest.tscn 2>&1 | grep -E "Thread|thread|VFPS|PFPS|Batch|non-blocking" --line-buffered
