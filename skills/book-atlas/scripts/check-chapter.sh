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

# coverage 의 "상태" 표(마지막 열 헤더가 정확히 상태인 표)를 찾아 헤더에서
# "정리 노트" 칸과 "상태" 칸의 위치를 잡고, 그 뒤 데이터 행마다 그 두 칸만
# "정리노트<TAB>상태" 한 줄로 뽑아낸다(검사 2·3 이 함께 쓴다). 헤더 행
# (`| ... | 상태 |`) 다음 줄은 구분자(|---|)이므로 건너뛰고, 그 뒤 `|` 로
# 시작하는 행이 끊길 때까지를 데이터 행으로 본다. 마지막 헤더가 "설명 보강"
# 인 표 2(코드·예제 커버리지)는 이 정규식에 안 걸려 자동으로 제외된다.
# [fix round 1] 이전에는 행 전체 문자열에서 [[...]] 를 그러모아 검사 2를
# 돌렸다 — "상태" 칸의 사유 텍스트가 다른 노트를 언급하면(예: `부분 — 세부
# 예제는 [[04-later]]에서 다룸`) 그 링크까지 "참조하니 있어야 하는 노트"로
# 잘못 걸렸다. split_row 로 칸을 나눠 "정리 노트" 칸만 보도록 고쳤다. 헤더에
# "정리 노트"라는 이름의 칸이 없으면(스키마 이탈 대비) 상태 칸 바로 앞 칸으로
# 대신한다.
# bash 3.2 노트: [[:space:]] 는 POSIX 문자 클래스라 이 awk 빌드에서 \s·\t
# 보다 안전하다. awk 자체 배열(hdr/cell)은 이 스크립트가 피하는 "bash 배열"
# 과 무관 — DT 원본·check-note.sh 모두 awk 내부 배열은 자유롭게 쓴다.
table_found=0
state_pairs=""
if [ -f "$COV" ]; then
  if grep -qE '^\|.*\|[[:space:]]*상태[[:space:]]*\|[[:space:]]*$' "$COV"; then
    table_found=1
    state_pairs=$(awk '
      function trim(v) { gsub(/^[[:space:]]+/, "", v); gsub(/[[:space:]]+$/, "", v); return v }
      function split_row(line, out,    n, i, c, cnt) {
        n = split(line, c, "|")
        cnt = 0
        for (i = 1; i <= n; i++) {
          if (i == 1 && trim(c[i]) == "") continue
          if (i == n && trim(c[i]) == "") continue
          cnt++; out[cnt] = trim(c[i])
        }
        return cnt
      }
      mode == "" {
        if ($0 ~ /^\|.*\|[[:space:]]*상태[[:space:]]*\|[[:space:]]*$/) {
          ncols = split_row($0, hdr)
          statuscol = ncols
          notecol = 0
          for (i = 1; i <= ncols; i++) if (hdr[i] == "정리 노트") { notecol = i; break }
          if (notecol == 0) notecol = ncols - 1
          mode = "sep"
        }
        next
      }
      mode == "sep" { mode = "rows"; next }
      mode == "rows" {
        if ($0 !~ /^\|/) { mode = ""; next }
        m = split_row($0, cell)
        nv = (notecol >= 1 && notecol <= m) ? cell[notecol] : ""
        sv = (statuscol >= 1 && statuscol <= m) ? cell[statuscol] : ""
        printf "%s\t%s\n", nv, sv
        next
      }
    ' "$COV")
  fi
fi

# --- (검사 2·3 의 전제) coverage 에 "상태" 표가 존재하는가 ---
# [fix round 1 — controller ruling] 표가 아예 없으면 검사 2·3 이 볼 대상이
# 없어 조용히 OK 를 내는데, 이는 "위반이 없다"와 구별되지 않는다 — coverage
# 의 존재 이유(기계적 누락 탐지)를 무력화하는 침묵이므로 별도 실패로 알린다.
if [ -f "$COV" ]; then
  if [ "$table_found" -eq 1 ]; then
    ok "상태 표 발견"
  else
    bad "상태 표 없음(_coverage.md) — 마지막 열 헤더가 정확히 상태 인 표가 없음"
  fi
fi

# --- 2) coverage(상태 표) 의 "정리 노트" 칸이 참조하는 노트가 실제로 존재하는가 ---
if [ "$table_found" -eq 1 ]; then
  ref_miss=""
  while IFS=$'\t' read -r notecell _statuscell; do
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      name="${link#\[\[}"; name="${name%\]\]}"
      [ -f "$DIR/$name.md" ] || ref_miss="$ref_miss [[$name]]"
    done <<LINKS
$(printf '%s\n' "$notecell" | grep -oE '\[\[[^]]+\]\]' || true)
LINKS
  done <<PAIRS
$state_pairs
PAIRS
  if [ -z "$ref_miss" ]; then ok "coverage 참조 노트 존재"; else bad "coverage 참조 노트 없음:$ref_miss"; fi
fi

# --- 3) 상태 칸이 사유 없이 "미반영"·"부분" 뿐인 행 ---
# `미반영 — 이유` 처럼 뒤에 텍스트가 더 있으면 사유가 있는 것으로 보아
# 통과시킨다. 트리밍 후 정확히 그 두 낱말뿐일 때만 사유 없음으로 센다.
if [ "$table_found" -eq 1 ]; then
  reason_miss=""
  while IFS=$'\t' read -r _notecell statuscell; do
    if [ "$statuscell" = "미반영" ] || [ "$statuscell" = "부분" ]; then
      reason_miss="$reason_miss $statuscell"
    fi
  done <<PAIRS
$state_pairs
PAIRS
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
  gate_err=""
  for f in "$DIR"/[0-9][0-9]*-*.md; do
    [ -f "$f" ] || continue
    "$NOTE_CHECKER" "$f" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 2 ]; then
      gate_miss="$gate_miss $(basename "$f")"
    elif [ "$rc" -eq 1 ]; then
      # [fix round 1 — controller ruling] exit 1 은 검사 실패(exit 2)가
      # 아니라 check-note.sh 자신의 사용법·입력 오류다(예: 노트 디렉터리
      # 위로 4단계 안에 _glossary.md 를 못 찾음). 이전에는 이 값을 gate_miss
      # 어디에도 안 걸려 조용히 통과로 취급했다 — 실패도 성공도 아닌 상태가
      # 사라지는 것이므로 별도 사유로 남긴다.
      gate_err="$gate_err $(basename "$f")"
    fi
  done
  if [ -z "$gate_miss" ]; then ok "노트 게이트 통과"; else bad "노트 게이트 실패:$gate_miss"; fi
  if [ -n "$gate_err" ]; then bad "노트 게이트 오류(exit 1):$gate_err"; fi
fi

# --- 6) 선언 연속성 — coverage 구간이 챕터를 빈틈없이 덮는가 (SKILL-001) ---
# 표기 정규화: 괄호 주석 제거 → 남은 숫자의 첫/끝을 시작/끝으로.
# 예) "371(14행)–375(11행)" → 371 375 · "284(상단)" → 284 284
gaps=""
prev_end=""
ranges=$(grep -E '^\| *[0-9]' "$COV" \
  | sed -e 's/|/\t/g' \
  | cut -f2 \
  | sed -e 's/([^)]*)//g' -e 's/[^0-9]\{1,\}/ /g' -e 's/^ *//' -e 's/ *$//' \
  | awk 'NF{ if (NF==1) print $1, $1; else print $1, $NF }' \
  | sort -n -k1,1)

while read -r s e; do
  [ -z "$s" ] && continue
  if [ -n "$prev_end" ]; then
    expect=$((prev_end + 1))
    if [ "$s" -gt "$expect" ]; then
      if [ "$s" -eq "$((expect + 1))" ]; then
        gaps="$gaps $expect"
      else
        gaps="$gaps $expect–$((s - 1))"
      fi
    fi
  fi
  [ -z "$prev_end" ] || [ "$e" -gt "$prev_end" ] && prev_end="$e"
done <<EOF
$ranges
EOF

if [ -n "$gaps" ]; then
  bad "선언 구간에 구멍:$gaps 쪽 — 어느 노트도 이 쪽을 선언하지 않는다"
else
  ok "선언 구간이 챕터를 덮음"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "check-chapter: PASS  $DIR"
  exit 0
fi
echo "check-chapter: FAIL  $DIR" >&2
exit 2
