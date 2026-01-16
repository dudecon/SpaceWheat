#!/bin/bash
# SpaceWheat Automated Playtest Script
# Runs gameplay tests and reports results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_FILE="/tmp/spacewheat_playtest_$(date +%Y%m%d_%H%M%S).log"

echo "========================================"
echo "🎮 SpaceWheat Automated Playtest"
echo "========================================"
echo ""
echo "Log file: $LOG_FILE"
echo ""

# Kill any existing Godot processes
pkill -9 -f "godot.*SpaceWheat" 2>/dev/null || true
sleep 1

# Run the autoplay test
echo "Starting automated gameplay test..."
echo ""

# Run with timeout
timeout 60 godot --headless . --script res://Tests/test_gameplay_autoplay.gd 2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "========================================"

# Check for errors in log
ERRORS=$(grep -c "ERROR\|❌ FAIL" "$LOG_FILE" 2>/dev/null || echo "0")
PASSES=$(grep -c "✅ PASS\|✓" "$LOG_FILE" 2>/dev/null || echo "0")

echo "📊 Summary:"
echo "   Passes: $PASSES"
echo "   Errors: $ERRORS"
echo "   Exit code: $EXIT_CODE"
echo ""

if [ "$EXIT_CODE" -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed - check log: $LOG_FILE"
    exit 1
fi
