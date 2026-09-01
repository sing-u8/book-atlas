#!/usr/bin/env bash
# install.sh — book-atlas 를 ~/.claude/skills/ 에 설치한다
set -euo pipefail
SRC="$(cd "$(dirname "$0")/skills/book-atlas" && pwd)"
DST="$HOME/.claude/skills/book-atlas"
mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"
echo "installed: $DST"
