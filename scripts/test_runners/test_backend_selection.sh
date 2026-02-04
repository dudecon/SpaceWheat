#!/bin/bash
# Test the new ComputeBackendSelector system

echo "========================================================================="
echo "COMPUTE BACKEND SELECTION TEST"
echo "========================================================================="
echo ""

cd /home/tehcr33d/ws/SpaceWheat

echo "TEST 1: Headless (should select NATIVE_CPU)"
echo "---------------------------------------------------------------------"
godot --headless VisualBubbleTest.tscn 2>&1 | grep -E "ComputeSelector|QuantumForceSystem" | head -5 &
PID=$!
sleep 5
kill $PID 2>/dev/null
echo ""

echo "TEST 2: With Zink (should detect software renderer, select NATIVE_CPU)"
echo "---------------------------------------------------------------------"
export DISPLAY=:0
export MESA_LOADER_DRIVER_OVERRIDE=zink
godot VisualBubbleTest.tscn 2>&1 | grep -E "ComputeSelector|QuantumForceSystem|Software renderer" | head -10 &
PID=$!
sleep 8
kill $PID 2>/dev/null
echo ""

echo "========================================================================="
echo "Expected Results:"
echo "  • Headless: NATIVE_CPU backend"
echo "  • Zink: Software renderer detected → NATIVE_CPU backend"
echo "  • Real GPU: GPU_COMPUTE backend (can't test in WSL2)"
echo "========================================================================="
