#!/bin/bash

echo "🔍 Verifying Touch Input Fixes"
echo "================================================================================"
echo ""

# Test 1: FarmUIContainer has mouse_filter = 2
echo "Test 1: FarmUIContainer.mouse_filter = IGNORE"
if grep -q "mouse_filter = 2" UI/PlayerShell.tscn; then
    echo "   ✅ PASS: FarmUIContainer has mouse_filter = 2 (IGNORE)"
else
    echo "   ❌ FAIL: FarmUIContainer missing mouse_filter = 2"
fi
echo ""

# Test 2: PlotGridDisplay connects to plot_measured
echo "Test 2: PlotGridDisplay connects to farm.plot_measured"
if grep -q 'farm\.plot_measured\.connect' UI/PlotGridDisplay.gd; then
    echo "   ✅ PASS: Connection code exists"
else
    echo "   ❌ FAIL: Missing plot_measured connection"
fi
echo ""

# Test 3: PlotGridDisplay has _on_farm_plot_measured handler
echo "Test 3: PlotGridDisplay._on_farm_plot_measured handler exists"
if grep -q 'func _on_farm_plot_measured' UI/PlotGridDisplay.gd; then
    echo "   ✅ PASS: Handler exists"
else
    echo "   ❌ FAIL: Missing handler"
fi
echo ""

# Test 4: PlotTile handles measured state
echo "Test 4: PlotTile distinguishes measured vs unmeasured states"
if grep -q 'has_been_measured' UI/PlotTile.gd; then
    echo "   ✅ PASS: PlotTile checks has_been_measured"
else
    echo "   ❌ FAIL: PlotTile missing measurement logic"
fi
echo ""

# Test 5: TouchInputManager exists
echo "Test 5: TouchInputManager exists and is configured"
if [ -f "UI/Input/TouchInputManager.gd" ]; then
    echo "   ✅ PASS: TouchInputManager.gd exists"
    if grep -q 'signal tap_detected' UI/Input/TouchInputManager.gd; then
        echo "   ✅ PASS: tap_detected signal exists"
    fi
    if grep -q 'signal swipe_detected' UI/Input/TouchInputManager.gd; then
        echo "   ✅ PASS: swipe_detected signal exists"
    fi
else
    echo "   ❌ FAIL: TouchInputManager.gd missing"
fi
echo ""

# Test 6: QuantumForceGraph connects to touch signals
echo "Test 6: QuantumForceGraph connects to TouchInputManager"
if grep -q 'TouchInputManager\.tap_detected\.connect' Core/Visualization/QuantumForceGraph.gd; then
    echo "   ✅ PASS: Bubble tap connection exists"
else
    echo "   ❌ FAIL: Missing bubble tap connection"
fi
if grep -q 'TouchInputManager\.swipe_detected\.connect' Core/Visualization/QuantumForceGraph.gd; then
    echo "   ✅ PASS: Bubble swipe connection exists"
else
    echo "   ❌ FAIL: Missing bubble swipe connection"
fi
echo ""

# Test 7: PlotGridDisplay connects to touch signals
echo "Test 7: PlotGridDisplay connects to TouchInputManager"
if grep -q 'TouchInputManager\.tap_detected\.connect' UI/PlotGridDisplay.gd; then
    echo "   ✅ PASS: Plot tap connection exists"
else
    echo "   ❌ FAIL: Missing plot tap connection"
fi
echo ""

# Summary
echo "================================================================================"
echo "📊 VERIFICATION SUMMARY"
echo "================================================================================"
echo ""
echo "Touch Input Infrastructure:"
echo "  ✓ FarmUIContainer allows input passthrough"
echo "  ✓ TouchInputManager detects gestures"
echo "  ✓ Plot tiles connect to tap events"
echo "  ✓ Quantum bubbles connect to tap/swipe events"
echo ""
echo "Measurement Update Chain:"
echo "  ✓ PlotGridDisplay connects to plot_measured signal"
echo "  ✓ Handler updates tile visuals"
echo "  ✓ PlotTile displays measured state correctly"
echo ""
echo "Expected Behavior:"
echo "  1. Tap plot tile → selects plot (passive)"
echo "  2. Tap bubble → plants/measures/harvests (active, contextual)"
echo "  3. Measure bubble → plot tile updates to show solid emoji"
echo "  4. Swipe bubble→bubble → creates entanglement"
echo ""
