#!/bin/bash
# Interactive Quest Playtest - Full Gameplay Loop
#
# This launches SpaceWheat with the interactive quest playtest.
# Play with your keyboard while the script guides you through:
#   1. Accept quests from factions
#   2. Farm quantum resources (Explore -> Measure -> Pop)
#   3. Complete quests to earn vocabulary
#   4. Unlock new factions with your vocabulary
#   5. Inject vocabulary into biomes (BUILD mode)

echo ""
echo "========================================"
echo "  SPACEWHEAT QUEST PLAYTEST"
echo "========================================"
echo ""
echo "Starting interactive playtest..."
echo ""
echo "KEY CONTROLS:"
echo "  [C]     - Open/close Quest Board"
echo "  [UIOP]  - Select quest slots"
echo "  [Q/E/R] - Tool actions"
echo "  [1-4]   - Select tool"
echo "  [TAB]   - Toggle PLAY/BUILD mode"
echo "  [ESC]   - Close overlays"
echo ""

cd "$(dirname "$0")"
godot --script res://Tests/interactive_quest_playtest.gd
