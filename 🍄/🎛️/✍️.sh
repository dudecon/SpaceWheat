#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
XDG_ROOT="${XDG_ROOT:-${PROJECT_ROOT}/.godot}"
APPLICATION_NAME="${APPLICATION_NAME:-SpaceWheat - Quantum Farm}"
# Match Godot's user:// resolution when XDG_DATA_HOME is set
GODOT_USER_DIR="${GODOT_USER_DIR:-${XDG_ROOT}/godot/app_userdata/${APPLICATION_NAME}}"
QUEUE_FILE="${QUEUE_FILE:-${GODOT_USER_DIR}/rig/queue.jsonl}"

if [ $# -lt 1 ]; then
  echo "Usage: $0 '{\"turn\":1,\"action\":\"resource_snapshot\"}'"
  exit 1
fi

mkdir -p "$(dirname "$QUEUE_FILE")"
echo "$1" >> "$QUEUE_FILE"
echo "Queued: $1"
