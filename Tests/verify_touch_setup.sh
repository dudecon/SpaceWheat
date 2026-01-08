#!/bin/bash

# Quick Touch Input Setup Verification
# Checks if touch input connections are established correctly

echo "🔍 Verifying Touch Input Setup..."
echo "================================================================"

timeout 15 godot --headless scenes/FarmView.tscn 2>&1 | tee /tmp/touch_verify.log | \
    grep -E "FarmUIContainer mouse_filter|Touch:|✅ Touch|❌"

echo ""
echo "================================================================"
echo "📋 Expected Output:"
echo "   ✅ FarmUIContainer mouse_filter set to IGNORE"
echo "   ✅ Touch: Tap-to-select connected (PlotGridDisplay)"
echo "   ✅ Touch: Tap-to-measure connected (QuantumForceGraph)"
echo "   ✅ Touch: Swipe-to-entangle connected (QuantumForceGraph)"
echo ""
echo "Full log saved to: /tmp/touch_verify.log"
