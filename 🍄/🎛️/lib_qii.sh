#!/bin/bash
set -euo pipefail

# QII log/vocab helpers for emoji scripts

QII_VOCAB_FILE="${QII_VOCAB_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/VOCAB_QII.tsv}"
QII_TOKEN_DIR="${QII_TOKEN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs/tokens}"

qii_init_vocab() {
  local emoji="$1"
  local timestamp="$2"
  mkdir -p "$QII_TOKEN_DIR"
  QII_TOKEN_LOG="${QII_TOKEN_DIR}/${emoji}${timestamp}.tok"
  export QII_TOKEN_LOG
  {
    echo "VOCAB_FILE=${QII_VOCAB_FILE}"
    echo "SCRIPT=${emoji}"
    echo "START=${timestamp}"
  } >> "$QII_TOKEN_LOG"
}

qii_token() {
  local code="$1"
  local note="${2:-}"
  local ts
  ts="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  if [ -n "$note" ]; then
    echo "${ts}\t${code}\t${note}" >> "$QII_TOKEN_LOG"
  else
    echo "${ts}\t${code}" >> "$QII_TOKEN_LOG"
  fi
}
