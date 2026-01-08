#!/bin/bash

echo "🧪 Testing Input Architecture"
echo "=============================="
echo ""
echo "Running game - check console for:"
echo "1. Press C → Should see 'Modal stack: [QuestBoard]'"
echo "2. Press U → Should see QuestBoard handling (not farm plot selection)"
echo "3. Press ESC → Should see 'Modal stack: []'"
echo ""
echo "If UIOP still selects farm plots with quest board open, the bug persists."
echo ""

timeout 60 godot --headless --quit-after 15 2>&1 | grep -E "Modal stack|QuestBoard|PlayerShell.*input|FarmInputHandler|KEY.*85|KEY.*73|KEY.*79|KEY.*80|KEY.*67|slot|plot.*select" | head -50
