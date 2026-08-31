#!/usr/bin/env bash
# check-note.sh — book-atlas 절 노트 완료 게이트 (기계 검사)
# usage: check-note.sh <note.md>
# exit: 0 통과 / 2 검사 실패 / 1 사용법·입력 오류
# bash 3.2 호환 (macOS 기본 bash) — 배열·mapfile·연관배열 사용 금지, local 은 가능
set -uo pipefail

# 로케일을 C로 고정한다. sort -u 가 UTF-8 로케일의 콜레이션 때문에 서로 다른
# 한글 문자열을 "같다"고 보고 하나를 지워버릴 수 있고, grep/awk 의 바이트
# 단위 매칭도 이 스크립트가 하는 일(리터럴 부분 문자열 대조)에는 C 로케일이
# 더 정확하다 — 호출하는 쪽(훅·테스트 하니스·사용자 셸)의 로케일에 이
# 스크립트가 휘둘리지 않도록 스크립트 자신이 고정한다.
export LC_ALL=C

NOTE="${1:-}"
if [ -z "$NOTE" ]; then
  echo "usage: check-note.sh <note.md>" >&2
  exit 1
fi
if [ ! -f "$NOTE" ]; then
  echo "check-note: 파일 없음: $NOTE" >&2
  exit 1
fi

# --- 1) 인자 · vault 루트(= 용어집 보유 디렉터리) 탐색 ---
# 노트 디렉터리에서 시작해 위로 최대 4단계까지 _glossary.md 를 찾는다.
# 찾은 디렉터리가 곧 9)의 노트-링크 존재 검사(find)가 쓰는 vault 루트다.
dir="$(dirname "$NOTE")"
VROOT=""
for i in 1 2 3 4; do
  cand="$(cd "$dir" 2>/dev/null && pwd)"
  if [ -n "$cand" ] && [ -f "$cand/_glossary.md" ]; then
    VROOT="$cand"
    break
  fi
  dir="$dir/.."
done
if [ -z "$VROOT" ]; then
  echo "check-note: 용어집(_glossary.md)을 노트 디렉터리에서 위로 4단계 이내에서 찾을 수 없음: $NOTE" >&2
  exit 1
fi

SEP='<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->'
FAILED=0

ok()  { printf '  OK   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1" >&2; FAILED=1; }

# [[대상]] 하나(대괄호를 이미 벗긴 raw item)를 대조용 슬러그로 정규화해
# 표준출력에 한 줄 인쇄한다. |별칭은 앞부분만 취하고, #앵커는
# _glossary#s → 개념 s 로, 그 외 _ 접두(_assets 임베드·_chapter 등 스킬
# 내부 참조)는 아무것도 출력하지 않고 건너뛴다.
# bash 3.2 노트: 이 case 문은 반드시 $(...) 명령 치환 "밖"의 함수로 존재해야
# 한다 — 이 bash 빌드는 case 안의 괄호 있는 패턴(예: abc*) )을 $(...) 안에
# 직접 두면 그 ')'를 명령 치환의 닫는 괄호로 잘못 세어 "syntax error near
# unexpected token `;;'"를 낸다(단순 case 하나만 넣어도 재현됨). 함수로
# 빼서 "밖"에서 정의하고 $(...) 안에서는 호출만 하면 문제가 없다.
resolve_term() {
  local item="$1" inner target
  inner="${item#\[\[}"
  inner="${inner%\]\]}"
  target="${inner%%|*}"
  case "$target" in
    _glossary\#*) printf '%s\n' "${target#_glossary\#}" ;;
    _*) ;;
    *\#*) printf '%s\n' "${target%%#*}" ;;
    *) printf '%s\n' "$target" ;;
  esac
}

# --- 2) 구분자 존재 확인 + 스킬 영역(구분자 위) 추출 ---
# sed '/pat/q' 는 매치된 줄까지(그 줄 포함) 출력하고 종료한다. 구분자가 아예
# 없으면 매치가 나지 않아 자동 출력이 끝까지 이어져 파일 전체가 above 가
# 된다 — 그래서 구분자 유무는 grep 으로 따로, 먼저 확인한다.
if grep -qF "$SEP" "$NOTE"; then
  ok "구분자"
else
  bad "구분자 없음 — $SEP 필요"
fi
above=$(sed "/<!-- ==== 아래는 내 메모/q" "$NOTE")

# --- 3) frontmatter 7키 ---
if [ "$(sed -n '1p' "$NOTE")" = "---" ]; then
  fm=$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$NOTE")
  fm_miss=""
  for k in book chapter section title pages concepts status; do
    printf '%s\n' "$fm" | grep -q "^${k}:" || fm_miss="$fm_miss [$k]"
  done
  if [ -z "$fm_miss" ]; then ok "frontmatter 7키"; else bad "frontmatter 누락:$fm_miss"; fi
else
  fm=""
  bad "frontmatter 시작 --- 없음"
fi

# --- 4) 필수 H2 6개 (스킬 영역 안에서) ---
# "## 연결" 자체가 없으면 아래 7)의 연결-개수 검사는 실행하지 않는다 —
# 존재하지 않는 섹션의 항목 수를 세는 건 무의미하고, 사유를 "섹션 누락"
# 하나로 좁혀야 실패 노트마다 정확히 하나의 이유가 유지된다.
h2_miss=""
conn_h2_present=0
while IFS= read -r h; do
  [ -z "$h" ] && continue
  # 앵커 필수 — -F 부분 문자열 매칭이면 "### 개념"(H3로 격하) 이 "## 개념"
  # 을 부분 문자열로 포함해 거짓으로 통과한다("###"의 마지막 두 '#'+공백이
  # "## " 와 겹침). ^## 로 줄 시작을 고정하고 뒤는 공백 또는 줄 끝만 허용해
  # H3/H4 로 격하된 헤더를 확실히 걸러낸다 — :194 의 용어집 대조 패턴과 같은
  # 원칙.
  if printf '%s\n' "$above" | grep -qE "^## ${h}([[:space:]]|$)"; then
    [ "$h" = "연결" ] && conn_h2_present=1
  else
    h2_miss="$h2_miss [$h]"
  fi
done <<'H2LIST'
한눈에 보기
왜 이 절인가
본문 정리
개념
연결
스스로 확인
H2LIST
if [ -z "$h2_miss" ]; then ok "필수 H2 6개"; else bad "섹션 누락:$h2_miss"; fi

# --- 5) 코드펜스 짝수 ---
# 홀수(안 닫힌 펜스)면 아래 8)·9)의 펜스 제거·용어 대조를 통째로 건너뛴다 —
# awk 의 f=!f 토글이 문서 끝까지 뒤집힌 채로 남아 그 뒤 내용이 통째로
# 사라지거나 통째로 남는 식으로 대조 결과를 오염시키기 때문이다.
fence_n=$(printf '%s\n' "$above" | grep -c '^```' || true)
fence_ok=1
if [ $((fence_n % 2)) -ne 0 ]; then
  bad "코드펜스 홀수(${fence_n}개) — 이후 용어 대조 신뢰 불가"
  fence_ok=0
else
  ok "코드펜스 짝수(${fence_n}개)"
fi

# --- 6) 도표 ≥1 ---
if printf '%s\n' "$above" | grep -qE '^```(mermaid|text)$'; then
  ok "도표(코드펜스)"
elif printf '%s\n' "$above" | grep -qF '![[_assets/'; then
  ok "도표(임베드)"
else
  bad "도표 없음 — mermaid/text 코드펜스 또는 ![[_assets/ 임베드 필요"
fi

# --- 7) 연결 ≥2 ("## 연결" 이 4)에서 존재 확인됐을 때만) ---
if [ "$conn_h2_present" -eq 1 ]; then
  conn_block=$(printf '%s\n' "$above" | awk '/^## 연결/{f=1;next} f && /^## /{exit} f{print}')
  conn_n=$(printf '%s\n' "$conn_block" | grep -cE '^- \[\[.+\]\] — .+' || true)
  if [ "$conn_n" -ge 2 ]; then
    ok "연결 ${conn_n}개"
  else
    bad "연결 부족(${conn_n}개) — 2개 이상 필요. 형식: - [[대상]] — 설명"
  fi
fi

# --- 8) 펜스 제거 + 9) 용어 전수 대조 (5)에서 코드펜스가 짝수로 확인됐을 때만) ---
if [ "$fence_ok" -eq 1 ]; then
  stripped=$(printf '%s\n' "$above" | awk '/^```/{f=!f;next} !f')

  concepts_line=$(printf '%s\n' "$fm" | grep '^concepts:' || true)
  concepts_list=$(printf '%s\n' "$concepts_line" \
    | sed -E 's/^concepts:[[:space:]]*\[//; s/\][[:space:]]*$//' \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//')

  raw_links=$(printf '%s\n' "$stripped" | grep -oE '\[\[[^]]+\]\]' || true)

  term_list=$( {
    printf '%s\n' "$raw_links" | while IFS= read -r item; do
      [ -z "$item" ] && continue
      resolve_term "$item"
    done
    printf '%s\n' "$concepts_list"
  } | grep -v '^$' | sort -u )

  term_miss=""
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    if [ -n "$(find "$VROOT" -name "$t.md" -not -path '*/graph/*' 2>/dev/null)" ]; then
      continue
    fi
    if grep -qE "^## $t( |$)" "$VROOT/_glossary.md"; then
      continue
    fi
    term_miss="$term_miss [[$t]]"
  done <<EOF
$term_list
EOF
  if [ -z "$term_miss" ]; then ok "용어 전수 대조"; else bad "용어집에 없음:$term_miss"; fi
fi

# --- 10) 최종 판정 ---
if [ "$FAILED" -eq 0 ]; then
  echo "check-note: PASS  $NOTE"
  exit 0
fi
echo "check-note: FAIL  $NOTE" >&2
exit 2
