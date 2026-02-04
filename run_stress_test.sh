#!/bin/bash
## Run stress test with the FarmView scene and capture output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
cd "$PROJECT_ROOT"
LOG_DIR="${PROJECT_ROOT}/logs/stress_test"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_LOG="${LOG_DIR}/stress_test_output_${TIMESTAMP}.log"

echo "Starting SpaceWheat stress test..."
echo "=================================="
echo "Results will land in $OUTPUT_LOG"

# Run godot with the stress test integrated scene
# Use xvfb-run if available for headless rendering, otherwise run directly
if command -v xvfb-run &> /dev/null; then
    echo "Running with Xvfb (virtual display)..."
    timeout 180 xvfb-run -a godot Tests/StressTestIntegratedScene.tscn 2>&1 | tee "$OUTPUT_LOG"
else
    echo "Running directly..."
    timeout 180 godot Tests/StressTestIntegratedScene.tscn 2>&1 | tee "$OUTPUT_LOG"
fi

echo ""
echo "Stress test complete. Results saved to $OUTPUT_LOG"
echo ""
echo "=== KEY RESULTS ==="
grep -E "STRESS TEST|Cycles completed|Terminal|Coherence|oscillation|Trace" "$OUTPUT_LOG" | tail -30
