#!/usr/bin/env bash
# check-note-hook.sh — Claude Code PostToolUse 훅 래퍼
# stdin: 호스트가 주는 PostToolUse JSON
# exit: 0 통과 또는 비대상 / 2 게이트 실패(stderr 가 호스트로 되먹임된다)
# 대상: book-atlas vault 안의 절 노트 — 다섯 조건을 **전부** 만족하는 파일만.
#   1) `.md` 로 끝난다
#   2) basename 이 `_` 접두가 아니다 (`_chapter`·`_coverage`·`_glossary` 제외)
#   3) basename 이 숫자로 시작한다 (`01-…`)
#   4) 자기 디렉터리부터 위로 4단계 이내에 `_glossary.md` 를 가진 디렉터리가 있다
#   5) 그 디렉터리가 `_global/config.md` 도 함께 가진다 (= book-atlas vault 루트)
# 5)가 없으면 deep-tutor 책 모드 노트까지 걸려 남의 저장소 저장을 막는다 —
# 자세한 근거는 아래 has_vault_root_ancestor 주석.
# bash 3.2 호환 (macOS 기본 bash) — 배열·mapfile·연관배열 사용 금지
set -uo pipefail

# check-note.sh 와 같은 이유로 로케일을 C 로 고정한다 — 경로·파일명의 바이트
# 단위 대조가 호출하는 쪽(호스트 셸)의 로케일에 흔들리지 않도록.
export LC_ALL=C

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKER="$SELF_DIR/check-note.sh"

# 스킬을 지워도, 훅 설정이 남은 프로젝트가 저장할 때마다 깨지면 안 된다.
[ -x "$CHECKER" ] || exit 0

input=$(cat)

extract_path_with_python() {
  python3 -c '
import json
import os
import sys

try:
    event = json.load(sys.stdin)
except (json.JSONDecodeError, TypeError, ValueError):
    raise SystemExit(0)

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    raise SystemExit(0)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    raise SystemExit(0)

cwd = event.get("cwd")
if not isinstance(cwd, str) or not cwd:
    cwd = os.getcwd()

path = os.path.expanduser(path)
if not os.path.isabs(path):
    path = os.path.normpath(os.path.join(cwd, path))
print(path)
'
}

extract_path_fallback() {
  # python3 가 없는 환경용. JSON 이스케이프는 풀지 않는다 — 평범한 경로만 본다.
  marker='"tool_input"'
  after_tool_input="${input#*$marker}"
  [ "$after_tool_input" = "$input" ] && return 0
  printf '%s' "$after_tool_input" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -n 's/.*"\([^"]*\)"$/\1/p'
}

# has_vault_root_ancestor <디렉터리> — 자기 자신부터 위로 4단계까지 훑어
# `_glossary.md` **와** `_global/config.md` 를 **둘 다** 가진 디렉터리가 있으면 0.
# 그 디렉터리가 book-atlas vault 루트다 — `build-graph.py` 가 vault 루트를
# 판정하는 기준(`_global/config.md`)과 같은 것을 본다.
#
# 두 파일을 **한 디렉터리에서 동시에** 요구하는 이유: `_glossary.md` 하나만 보면
# deep-tutor 책 모드 저장소(`{domain}-notes/chapter-NN/NN-slug.md` — 챕터마다
# `_glossary.md` 를 둔다)의 노트도 조건을 만족해, 두 저장소가 한 프로젝트의
# `.claude/settings.json` 아래 같이 있을 때 DT 노트의 저장이 이 훅에 잘못 막힌다.
# DT 챕터 디렉터리에는 `_glossary.md` 는 있어도 `_global/` 이 없고, DT 저장소
# 루트에는 `_global/config.md` 는 있어도 `_glossary.md` 가 없다(용어집이 챕터
# 단위다) — 그래서 "한 디렉터리에 둘 다"가 두 스킬을 정확히 가른다.
# 한쪽만 있는 디렉터리에서 멈추지 않고 계속 위로 올라간다.
#
# 저장소 이름(`*-atlas/`)을 문자열로 맞추지 않는 이유: 사용자가 디렉터리를
# 옮기거나 이름을 바꿔도, 테스트 픽스처처럼 이름 규칙 밖에 있어도 같은 규칙으로
# 동작해야 한다(DT 훅이 고정 오프셋에서 겪은 결함의 교훈).
# 4단계인 이유: 노트는 vault 루트에서 1단계(챕터) 또는 2단계(Part+챕터) 아래에
# 있고, 여유 두 단계를 더 본다.
has_vault_root_ancestor() {
  dir="$1"
  i=0
  while [ "$i" -lt 4 ]; do
    if [ -f "$dir/_glossary.md" ] && [ -f "$dir/_global/config.md" ]; then
      return 0
    fi
    parent="${dir%/*}"
    [ -z "$parent" ] && parent="/"
    [ "$parent" = "$dir" ] && return 1
    dir="$parent"
    i=$((i + 1))
  done
  return 1
}

if command -v python3 >/dev/null 2>&1; then
  fp=$(printf '%s' "$input" | extract_path_with_python)
else
  fp=$(extract_path_fallback)
fi

[ -z "$fp" ] && exit 0

# 대상 판정 — 싼 검사부터.
case "$fp" in
  *.md) ;;
  *) exit 0 ;;
esac

base="${fp##*/}"

# `_chapter.md`·`_coverage.md`·`_glossary.md` 는 절 노트가 아니다.
case "$base" in
  _*) exit 0 ;;
esac

# 절 노트는 번호 접두(`01-`)로 시작한다.
case "$base" in
  [0-9]*) ;;
  *) exit 0 ;;
esac

dir="${fp%/*}"
[ "$dir" = "$fp" ] && exit 0

has_vault_root_ancestor "$dir" || exit 0

# 삭제·이동 직후라면 검사할 것이 없다.
[ -f "$fp" ] || exit 0

if out=$("$CHECKER" "$fp" 2>&1); then
  exit 0
fi

printf 'book-atlas 노트 게이트 실패 (%s) — 아래를 고친 뒤 다시 저장하세요.\n%s\n' "$fp" "$out" >&2
exit 2
