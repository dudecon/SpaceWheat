#!/bin/bash
set -euo pipefail

PROJECT_ROOT="/home/tehcr33d/ws/SpaceWheat"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
XDG_ROOT="/tmp/spacewheat_godot"
source "${SCRIPT_DIR}/lib_qii.sh"

mkdir -p "$LOG_DIR"
mkdir -p "$XDG_ROOT"

emoji="$(basename "$0" .sh)"
timestamp="$(date +"%Y%m%d_%H%M%S")"
log_file="${LOG_DIR}/${emoji}${timestamp}.log"
qii_init_vocab "$emoji" "$timestamp"
qii_token "S.QIIVOCAB" "script"
qii_token "G4.Q" "inject"
qii_token "G3.Q" "explore"
qii_token "G4.R" "remove"

cd "$PROJECT_ROOT"
export XDG_DATA_HOME="$XDG_ROOT"
export XDG_CONFIG_HOME="$XDG_ROOT"

set +e
{
  echo "Experiment: ${emoji}"
  echo "Started: $(date -Is)"
  echo "Command: godot --headless --path . --script Tests/claude_vocab_inject_remove_test.gd"
  echo
  godot --headless --path . --script Tests/claude_vocab_inject_remove_test.gd
} 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
set -e

echo "Exit status: ${status}" | tee -a "$log_file"
exit "$status"
