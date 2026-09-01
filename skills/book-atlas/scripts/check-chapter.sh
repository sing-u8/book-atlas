#!/usr/bin/env bash
# check-chapter.sh — book-atlas 챕터 완결 게이트 (기계 검사)
# usage: check-chapter.sh <챕터경로>
# exit: 0 통과 / 2 검사 실패 / 1 사용법·입력 오류
# check-note.sh 가 노트 한 편이 노트답게 생겼는가를 본다면, 이 스크립트는
# 챕터 전체 — coverage 가 참조하는 노트가 실제로 있는지, 미해결 상태가
# 남았는지, 고아 노트는 없는지, 노트들이 개별 게이트를 통과하는지 — 를 본다.
# bash 3.2 호환 (macOS 기본 bash) — 배열·mapfile·연관배열 사용 금지
set -uo pipefail
# check-note.sh 와 같은 이유로 로케일을 C 로 고정한다 — grep/awk 의 한글
# 리터럴 대조가 호출하는 쪽의 로케일에 흔들리지 않도록 스크립트 자신이
# 고정한다.
export LC_ALL=C

DIR="${1:-}"
if [ -z "$DIR" ]; then
  echo "usage: check-chapter.sh <챕터경로>" >&2
  exit 1
fi
if [ ! -d "$DIR" ]; then
  echo "check-chapter: 디렉터리 없음: $DIR" >&2
  exit 1
fi
DIR="${DIR%/}"

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTE_CHECKER="$SELF_DIR/check-note.sh"
COV="$DIR/_coverage.md"

FAILED=0
ok()  { printf '  OK   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1" >&2; FAILED=1; }

# --- 1) 필수 파일 ---
files_miss=""
for f in _chapter.md _coverage.md; do
  [ -f "$DIR/$f" ] || files_miss="$files_miss $f"
done
if [ -z "$files_miss" ]; then ok "필수 파일 2개"; else bad "필수 파일 없음:$files_miss"; fi

# 표 행(반드시 여는 파이프로 시작)에서 마지막 칸만 앞뒤 공백 없이 돌려준다.
# "닫는 파이프가 있으면 제거, 없어도 무해"이므로 닫는 파이프 유무를 따로
# 분기하지 않는다 — ${v%|} 는 대상이 아니면 그대로 돌려주는 특성을 그대로 쓴다.
last_cell() {
  local v="$1"
  v="${v%"${v##*[![:space:]]}"}"   # 행 끝 공백 제거
  v="${v%|}"                        # 닫는 파이프 제거(없어도 무해)
  v="${v##*|}"                      # 마지막 칸만 남김
  v="${v#"${v%%[![:space:]]*}"}"   # 칸 앞 공백 제거
  v="${v%"${v##*[![:space:]]}"}"   # 칸 뒤 공백 제거
  printf '%s\n' "$v"
}

# --- coverage 의 "상태" 표(마지막 열 헤더가 정확히 상태인 표) 데이터 행을
# 모은다. 헤더 행(`| ... | 상태 |`) 다음 줄은 구분자(|---|)이므로 건너뛰고,
# 그 뒤 `|` 로 시작하는 행이 끊길 때까지를 데이터 행으로 본다. 마지막 헤더가
# "설명 보강"인 표 2(코드·예제 커버리지)는 이 정규식에 안 걸려 자동으로
# 제외된다. bash 3.2 노트: [[:space:]] 는 POSIX 문자 클래스라 이 awk 빌드에서
# \s·\t 보다 안전하다.
state_rows=""
if [ -f "$COV" ]; then
  state_rows=$(awk '
    mode == "" {
      if ($0 ~ /^\|.*\|[[:space:]]*상태[[:space:]]*\|[[:space:]]*$/) mode = "sep"
      next
    }
    mode == "sep" { mode = "rows"; next }
    mode == "rows" {
      if ($0 ~ /^\|/) { print; next }
      mode = ""
      next
    }
  ' "$COV")
fi

# --- 2) coverage(상태 표) 가 참조하는 노트가 실제로 존재하는가 ---
if [ -f "$COV" ]; then
  ref_miss=""
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    name="${link#\[\[}"; name="${name%\]\]}"
    [ -f "$DIR/$name.md" ] || ref_miss="$ref_miss [[$name]]"
  done <<LINKS
$(printf '%s\n' "$state_rows" | grep -oE '\[\[[^]]+\]\]' || true)
LINKS
  if [ -z "$ref_miss" ]; then ok "coverage 참조 노트 존재"; else bad "coverage 참조 노트 없음:$ref_miss"; fi
fi

# --- 3) 상태 칸이 사유 없이 "미반영"·"부분" 뿐인 행 ---
# `미반영 — 이유` 처럼 뒤에 텍스트가 더 있으면 사유가 있는 것으로 보아
# 통과시킨다. 트리밍 후 정확히 그 두 낱말뿐일 때만 사유 없음으로 센다.
if [ -f "$COV" ]; then
  reason_miss=""
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    val=$(last_cell "$row")
    if [ "$val" = "미반영" ] || [ "$val" = "부분" ]; then
      reason_miss="$reason_miss $val"
    fi
  done <<ROWS
$state_rows
ROWS
  if [ -z "$reason_miss" ]; then ok "coverage 사유 없는 미반영·부분 없음"; else bad "사유 없는$reason_miss"; fi
fi

# --- 4) 고아 노트 없음 — 챕터 안 노트는 전부 coverage 본문에 등장 ---
if [ -f "$COV" ]; then
  orphan=""
  for f in "$DIR"/[0-9][0-9]*-*.md; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    stem="${b%.md}"
    grep -qF "[[$stem]]" "$COV" || orphan="$orphan $b"
  done
  if [ -z "$orphan" ]; then ok "고아 노트 없음"; else bad "고아 노트:$orphan"; fi
fi

# --- 5) 챕터의 모든 노트가 check-note.sh 를 통과하는가 ---
if [ ! -x "$NOTE_CHECKER" ]; then
  bad "check-note.sh 를 찾을 수 없음: $NOTE_CHECKER"
else
  gate_miss=""
  for f in "$DIR"/[0-9][0-9]*-*.md; do
    [ -f "$f" ] || continue
    "$NOTE_CHECKER" "$f" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 2 ]; then gate_miss="$gate_miss $(basename "$f")"; fi
  done
  if [ -z "$gate_miss" ]; then ok "노트 게이트 통과"; else bad "노트 게이트 실패:$gate_miss"; fi
fi

if [ "$FAILED" -eq 0 ]; then
  echo "check-chapter: PASS  $DIR"
  exit 0
fi
echo "check-chapter: FAIL  $DIR" >&2
exit 2
