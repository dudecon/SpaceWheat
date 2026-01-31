#!/bin/bash

# 🌾 - SpaceWheat Visual Bubble Test
# Watch quantum bubbles evolve and interact

cd "/home/tehcr33d/ws/SpaceWheat"

echo "🌾 Visual Bubble Test (20s)"
echo "==========================="
echo "Quantum bubbles evolving..."
echo ""

# Auto-close after 20 seconds
timeout 20 godot --scene VisualBubbleTest.tscn
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "✅ Test completed (timeout)"
else
    echo ""
    echo "✅ Test completed"
fi
