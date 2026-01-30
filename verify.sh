#!/bin/bash
# Quick verification that native engines are working

echo "==================================================================="
echo "NATIVE ENGINE VERIFICATION"
echo "==================================================================="
echo ""
echo "Starting game for 10 seconds to capture initialization output..."
echo ""

# Run game briefly and capture output
timeout 10 godot --headless project.godot 2>&1 > /tmp/native_verify.log &
PID=$!

# Wait a bit for initialization
sleep 8

# Kill if still running
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo ""
echo "==================================================================="
echo "RESULTS:"
echo "==================================================================="
echo ""

# Check for native evolution
if grep -q "MultiBiomeLookaheadEngine.*registered" /tmp/native_verify.log; then
    echo "✅ PHASE 1: Native Evolution - WORKING"
    grep "MultiBiomeLookaheadEngine.*registered" /tmp/native_verify.log | head -1
    grep "Mode:.*lookahead" /tmp/native_verify.log | head -1
else
    echo "⚠️  PHASE 1: Native Evolution - Not detected in output"
    echo "   (May need longer initialization time)"
fi

echo ""

# Check for force graph (won't show unless integrated yet)
if grep -q "ForceGraphEngine" /tmp/native_verify.log; then
    echo "✅ PHASE 2: Force Graph - DETECTED"
    grep "ForceGraphEngine" /tmp/native_verify.log | head -1
else
    echo "⏳ PHASE 2: Force Graph - Pending integration"
    echo "   (Code compiled, needs GDScript hookup)"
fi

echo ""
echo "==================================================================="
echo ""
echo "Full log saved to: /tmp/native_verify.log"
echo "To view: cat /tmp/native_verify.log | grep -E 'MultiBiome|lookahead'"
echo ""
