#!/usr/bin/env bash
# uninstall.sh — Claude Code 또는 Codex 설치본을 제거한다
set -euo pipefail

remove_one() {
  local destination="$1"
  rm -rf "$destination"
  echo "removed: $destination"
}

case "${1:---claude}" in
  --claude)
    remove_one "$HOME/.claude/skills/book-atlas"
    ;;
  --codex)
    remove_one "${CODEX_HOME:-$HOME/.codex}/skills/book-atlas"
    ;;
  --all)
    remove_one "$HOME/.claude/skills/book-atlas"
    remove_one "${CODEX_HOME:-$HOME/.codex}/skills/book-atlas"
    ;;
  *)
    echo "usage: $0 [--claude|--codex|--all]" >&2
    exit 1
    ;;
esac
