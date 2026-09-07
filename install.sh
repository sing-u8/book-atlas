#!/usr/bin/env bash
# install.sh — book-atlas 를 Claude Code 또는 Codex에 설치한다
set -euo pipefail
SRC="$(cd "$(dirname "$0")/skills/book-atlas" && pwd)"

install_one() {
  local destination="$1"
  mkdir -p "$destination"
  rsync -a --delete "$SRC/" "$destination/"
  echo "installed: $destination"
}

case "${1:---claude}" in
  --claude)
    install_one "$HOME/.claude/skills/book-atlas"
    ;;
  --codex)
    install_one "${CODEX_HOME:-$HOME/.codex}/skills/book-atlas"
    ;;
  --all)
    install_one "$HOME/.claude/skills/book-atlas"
    install_one "${CODEX_HOME:-$HOME/.codex}/skills/book-atlas"
    ;;
  *)
    echo "usage: $0 [--claude|--codex|--all]" >&2
    exit 1
    ;;
esac
