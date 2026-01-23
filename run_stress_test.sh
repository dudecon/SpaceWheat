#!/bin/bash
## Run stress test with the FarmView scene and capture output

echo "Starting SpaceWheat stress test..."
echo "=================================="

# Run godot with the stress test integrated scene
# Use xvfb-run if available for headless rendering, otherwise run directly
if command -v xvfb-run &> /dev/null; then
    echo "Running with Xvfb (virtual display)..."
    timeout 180 xvfb-run -a godot Tests/StressTestIntegratedScene.tscn 2>&1 | tee stress_test_output.log
else
    echo "Running directly..."
    timeout 180 godot Tests/StressTestIntegratedScene.tscn 2>&1 | tee stress_test_output.log
fi

echo ""
echo "Stress test complete. Results saved to stress_test_output.log"
echo ""
echo "=== KEY RESULTS ==="
grep -E "STRESS TEST|Cycles completed|Terminal|Coherence|oscillation|Trace" stress_test_output.log | tail -30
