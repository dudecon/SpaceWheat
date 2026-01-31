#!/bin/bash

# 🏋️‍♀️ - Performance & Frame Budget Analysis
# Detailed performance metrics and stress testing

cd "/home/tehcr33d/ws/SpaceWheat"

echo "🏋️‍♀️ Frame Budget Profiler"
echo "=========================="
echo "Measuring physics vs visual processing..."
echo "This will take ~40 seconds (warmup + 2 measurement phases)"
echo ""

# Run frame budget profiler (auto-exits after measurement)
godot --scene Tests/FrameBudgetProfilerScene.tscn
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Performance analysis completed"
else
    echo ""
    echo "⚠️  Analysis exited with code: $EXIT_CODE"
fi
