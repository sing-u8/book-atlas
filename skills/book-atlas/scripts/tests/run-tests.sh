#!/usr/bin/env bash
# run-tests.sh — book-atlas 스크립트 테스트. 케이스: expect <기대exit> <설명> -- <명령...>
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/.."; F="$HERE/fixtures"
pass=0; fail=0
expect() {
  local want="$1"; local desc="$2"; shift 2; [ "$1" = "--" ] && shift
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass+1)); echo "PASS  $desc"
  else fail=$((fail+1)); echo "FAIL  $desc (want $want got $got)"; fi
}
expect_out() {  # expect_out <패턴> <설명> -- <명령...> — 종료코드가 아니라 출력 내용을 본다
  local pat="$1"; local desc="$2"; shift 2; [ "$1" = "--" ] && shift
  if "$@" 2>&1 | grep -q "$pat"; then pass=$((pass+1)); echo "PASS  $desc"
  else fail=$((fail+1)); echo "FAIL  $desc (출력에 '$pat' 없음)"; fi
}

expect 0 "check-note: 통과 노트"        -- "$S/check-note.sh" "$F/vault/chapter-01-intro/01-what-is-retrieval.md"
expect 0 "check-note: draft 노트도 통과" -- "$S/check-note.sh" "$F/vault/chapter-01-intro/02-ranking.md"
expect 2 "check-note: H2 누락"          -- "$S/check-note.sh" "$F/invalid/missing-h2.md"
expect 2 "check-note: 미등재 용어"       -- "$S/check-note.sh" "$F/invalid/missing-term.md"
expect 2 "check-note: 연결 1개"         -- "$S/check-note.sh" "$F/invalid/one-link.md"
expect 2 "check-note: 코드펜스 홀수"     -- "$S/check-note.sh" "$F/invalid/odd-fence.md"
expect 2 "check-note: 도표 없음"        -- "$S/check-note.sh" "$F/invalid/no-diagram.md"
expect 2 "check-note: 구분자 없음"       -- "$S/check-note.sh" "$F/invalid/no-separator.md"
expect 1 "check-note: 인자 없음"        -- "$S/check-note.sh"

expect 0 "check-chapter: 통과 챕터"     -- "$S/check-chapter.sh" "$F/vault/chapter-01-intro"
expect 2 "check-chapter: 누락 참조+고아" -- "$S/check-chapter.sh" "$F/chapter-bad"
expect 1 "check-chapter: 인자 없음"     -- "$S/check-chapter.sh"

# --- build-graph 스모크: 픽스처 vault 를 임시로 복사해 실행, 산출 JS 를 검증 ---
TMP="$(mktemp -d)"; cp -R "$F/vault" "$TMP/v"
warn=$(python3 "$S/build-graph.py" "$TMP/v" 2>&1 >/dev/null); bg=$?
expect 0 "build-graph: exit 0" -- test "$bg" -eq 0
expect 0 "build-graph: 경고 1건(embedding)" -- test "$(printf '%s\n' "$warn" | grep -c '^경고: .*embedding')" -eq 1
python3 - "$TMP/v/graph/graph-data.js" <<'PY'; bgjs=$?
import json, re, sys, collections
raw = open(sys.argv[1], encoding="utf-8").read()
data = json.loads(re.sub(r'^window\.ATLAS_DATA\s*=\s*', '', raw.strip()).rstrip(';'))
nt = collections.Counter(n["type"] for n in data["nodes"])
lt = collections.Counter(l["type"] for l in data["links"])
assert nt == {"book":1,"chapter":2,"note":2,"concept":3}, nt
assert lt == {"toc":4,"covers":2,"mentions":2,"related":1,"note-link":1}, lt
assert data["book"]["vault"] == "TestVault"
ch = {n["id"]: n for n in data["nodes"] if n["type"]=="chapter"}
assert ch["chapter:chapter-01-intro"]["progress"] == {"done":1,"total":2}
assert ch["chapter:chapter-02-more"]["progress"] == {"done":0,"total":1}
con = {n["id"]: n for n in data["nodes"] if n["type"]=="concept"}
assert con["concept:retrieval"]["def"].startswith("질문과 관련된")
print("OK")
PY
expect 0 "build-graph: 데이터 계약 어서션" -- test "$bgjs" -eq 0
rm -rf "$TMP"

# --- 훅: stdin PostToolUse JSON → 대상 판정 → check-note.sh ---
note="$F/vault/chapter-01-intro/01-what-is-retrieval.md"
expect 0 "hook: atlas 노트에 게이트 실행" -- bash -c \
  'printf "{\"tool_input\":{\"file_path\":\"%s\"}}" "$1" | "$2"' _ "$note" "$S/check-note-hook.sh"
expect 0 "hook: 비대상 파일은 무시" -- bash -c \
  'printf "{\"tool_input\":{\"file_path\":\"/tmp/readme.md\"}}" | "$1"' _ "$S/check-note-hook.sh"

# --- SKILL-001 선언 연속성 — coverage 표 1 의 책 쪽 구간에 구멍이 있으면 잡는다 ---
# 처음부터 깨진 챕터를 새로 만들면 필수 파일·고아 노트 등 앞선 검사가 먼저
# 걸려 원인 추적이 어려워진다. 이미 통과하는 chapter-01-intro 를 복사한
# 뒤 _coverage.md 의 책 쪽 구간만 구멍이 생기게 바꿔, 이 검사만 실패하는
# 깨끗한 시험으로 만든다. 원본 행("2–4","5–8" 연속)의 구분자를 그대로
# 재사용해 "3–5","8–10" 으로 바꾸면 6–7 쪽이 어느 행에도 안 걸린다.
DASH=$(printf '\xe2\x80\x93')  # en dash(U+2013) — coverage 표기와 같은 구분자
tmp=$(mktemp -d)
mkdir -p "$tmp/vault"
cp -R "$F/vault/chapter-01-intro" "$tmp/vault/chapter-01-intro"
cp "$F/vault/_glossary.md" "$tmp/vault/_glossary.md"
python3 - "$tmp/vault/chapter-01-intro/_coverage.md" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
d = re.search(r"2(.)4", s).group(1)
s = s.replace("2" + d + "4", "3" + d + "5").replace("5" + d + "8", "8" + d + "10")
open(p, "w", encoding="utf-8").write(s)
PY
expect 2 "check-chapter: 선언 구멍이 있으면 exit 2" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
expect_out "6${DASH}7" "check-chapter: 선언 구멍(6-7쪽)을 잡는다" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
rm -rf "$tmp"

# --- SKILL-007 — 무괄호 "NN행" 표기에서 줄번호를 책쪽으로 오독하지 않는다 ---
# 파서는 원래 줄번호를 괄호 안에서만 지웠다(`36(26행)–39(24행)` 은 정상).
# ch03·ch04 처럼 괄호 없이 `2 27행–4 11행` 으로 쓰면 끝의 `11` 이 책쪽 끝으로
# 둔갑해 실제로는 없는 구멍을 무더기로 보고했다(4장 14건·3장 1건, 전부 거짓 경보).
# 아래는 그 표기에서 ①거짓 FAIL 이 안 나는지 ②그럼에도 진짜 구멍은 여전히
# 잡는지를 양방향으로 확인한다 — ②가 없으면 "검사를 무력화해서 통과시킨" 것과
# 구분되지 않는다.
tmp=$(mktemp -d)
mkdir -p "$tmp/vault"
cp -R "$F/vault/chapter-01-intro" "$tmp/vault/chapter-01-intro"
cp "$F/vault/_glossary.md" "$tmp/vault/_glossary.md"
python3 - "$tmp/vault/chapter-01-intro/_coverage.md" <<'PY2'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
d = re.search(r"2(.)4", s).group(1)
# 2–4 / 5–8 을 줄번호가 붙은 무괄호 표기로 바꾼다(범위 자체는 그대로 2–4·5–8)
s = s.replace("| 2" + d + "4 |", "| 2 27행" + d + "4 11행 |")
s = s.replace("| 5" + d + "8 |", "| 5 3행" + d + "8 19행 |")
open(p, "w", encoding="utf-8").write(s)
PY2
expect 0 "check-chapter: 무괄호 NN행 표기를 거짓 FAIL 하지 않는다" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
# 같은 표기에서 진짜 구멍을 뚫으면 여전히 잡아야 한다
python3 - "$tmp/vault/chapter-01-intro/_coverage.md" <<'PY2'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
d = re.search(r"5 3행(.)8 19행", s).group(1)
s = s.replace("| 5 3행" + d + "8 19행 |", "| 7 3행" + d + "8 19행 |")
open(p, "w", encoding="utf-8").write(s)
PY2
expect 2 "check-chapter: 무괄호 표기에서도 진짜 구멍은 잡는다" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
expect_out "5${DASH}6" "check-chapter: 그 구멍이 5-6쪽으로 보고된다" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
rm -rf "$tmp"

# --- SKILL-001 리뷰 후속 — ranges 추출이 '## 1.' 절에만 스코프되는지 ---
# 표 2(코드·예제 커버리지)에 숫자로 시작하는 행이 섞이면 두 방향으로 틀릴
# 수 있다: 표1 이 연속인데 표2 행이 끼면 거짓양성으로 멀쩡한 챕터를 막고,
# 표1 에 진짜 구멍이 있는데 표2 행이 그 쪽번호를 채우면 거짓음성으로
# 구멍을 놓친다. chapter-01-intro 를 복사해 표2 에 행을 추가해 두 방향
# 다 확인한다.
tmp=$(mktemp -d)
mkdir -p "$tmp/vault"
cp -R "$F/vault/chapter-01-intro" "$tmp/vault/chapter-01-intro"
cp "$F/vault/_glossary.md" "$tmp/vault/_glossary.md"
printf '| 12 | 노트 예시 | 보강 없음 |\n' >> "$tmp/vault/chapter-01-intro/_coverage.md"
expect 0 "check-chapter: 표2 숫자 행이 있어도 표1 이 연속이면 통과(거짓양성 방지)" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
rm -rf "$tmp"

tmp=$(mktemp -d)
mkdir -p "$tmp/vault"
cp -R "$F/vault/chapter-01-intro" "$tmp/vault/chapter-01-intro"
cp "$F/vault/_glossary.md" "$tmp/vault/_glossary.md"
python3 - "$tmp/vault/chapter-01-intro/_coverage.md" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
d = re.search(r"2(.)4", s).group(1)
s = s.replace("2" + d + "4", "3" + d + "5").replace("5" + d + "8", "8" + d + "10")
open(p, "w", encoding="utf-8").write(s)
PY
printf '| 6 | 노트 예시 | 보강 없음 |\n| 7 | 노트 예시 | 보강 없음 |\n' >> "$tmp/vault/chapter-01-intro/_coverage.md"
expect_out "6${DASH}7" "check-chapter: 표2 에 6·7 행이 있어도 구멍을 잡는다(거짓음성 방지)" -- "$S/check-chapter.sh" "$tmp/vault/chapter-01-intro"
rm -rf "$tmp"

# --- SKILL-002 경로 붙은 링크 (check-note.sh) ---
# 노트를 손으로 새로 쓰면 게이트 7종(frontmatter 7키·H2 6개·도표·연결 2개·
# 용어 대조·코드펜스 짝수·구분자)을 전부 통과해야 해서 SKILL-002 와 무관한
# 이유로 실패하기 쉽다. 이미 통과하는 01-what-is-retrieval.md 를 복사해
# "## 연결" 바로 아래에 경로 붙은 링크 한 줄만 추가한다.
tmp=$(mktemp -d)
mkdir -p "$tmp/vault"
cp -R "$F/vault/chapter-01-intro" "$tmp/vault/chapter-01-intro"
cp "$F/vault/_glossary.md" "$tmp/vault/_glossary.md"
python3 - "$tmp/vault/chapter-01-intro/01-what-is-retrieval.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "## 연결\n\n"
new = old + "- [[chapter-01-intro/02-ranking]] — 경로 붙은 링크(SKILL-002)\n"
assert old in s, "고정 앵커를 못 찾음 — 픽스처가 바뀌었는지 확인"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
expect 0 "check-note: 경로 붙은 링크를 통과시킨다(SKILL-002)" -- "$S/check-note.sh" "$tmp/vault/chapter-01-intro/01-what-is-retrieval.md"
rm -rf "$tmp"

# --- SKILL-003 basename 모호성 (check-chapter.sh) ---
# 같은 이름 노트가 vault 안에 여러 개면 경로 없는 [[04-summary]] 같은 링크가
# 어느 쪽을 가리키는지 알 수 없다 — 경고만 하고 종료코드는 바꾸지 않는다.
# p/chapter-03-y 와 p/chapter-07-w 에 같은 이름(04-summary)의 노트를 두고,
# 그 이름의 파일이 자기 폴더에 없는 p/chapter-06-z 가 경로 없이 그 이름을
# 링크하게 한다. [R14-② 반영] 링크한 폴더 자신에 그 이름 파일이 있으면
# 경고하지 않으므로, 진짜 모호성을 시험하려면 링크한 폴더에는 반드시
# 그 파일이 없어야 한다 — 그래서 두 번째 사본을 chapter-06-z 가 아니라
# 별도의 chapter-07-w 에 둔다.
tmp=$(mktemp -d)
mkdir -p "$tmp/v/p/chapter-03-y" "$tmp/v/p/chapter-06-z" "$tmp/v/p/chapter-07-w"
echo '## d' > "$tmp/v/_glossary.md"
printf '# a\n' > "$tmp/v/p/chapter-03-y/04-summary.md"
printf '# b\n' > "$tmp/v/p/chapter-07-w/04-summary.md"
printf '# c\n\n[[04-summary]]\n' > "$tmp/v/p/chapter-06-z/01-x.md"
expect_out "모호한 링크" "check-chapter: 모호한 basename 링크를 경고한다(SKILL-003)" -- "$S/check-chapter.sh" "$tmp/v/p/chapter-06-z"
rm -rf "$tmp"

# --- SKILL-003 R14-① _ 로 시작하는 링크는 경고하지 않는다 ---
# _coverage·_chapter·_glossary 같은 스킬 내부 파일은 같은 이름이 여러 장에
# 있는 게 설계상 정상이다(장마다 하나씩) — 노트가 아니므로 모호성 경고
# 대상이 아니다. expect_out 은 "패턴이 있으면 통과" 라 부재 확인엔 안 맞아
# 여기서는 부재를 직접 검사하는 bash -c 조합을 쓴다.
tmp=$(mktemp -d)
mkdir -p "$tmp/v/p/chapter-03-y" "$tmp/v/p/chapter-06-z"
echo '## d' > "$tmp/v/_glossary.md"
printf '# a\n' > "$tmp/v/p/chapter-03-y/_x.md"
printf '# b\n' > "$tmp/v/p/chapter-06-z/_x.md"
printf '# c\n\n[[_x]]\n' > "$tmp/v/p/chapter-06-z/01-y.md"
expect 0 "check-chapter: _ 접두 링크는 경고하지 않는다(SKILL-003 R14-①)" -- \
  bash -c '! "$1" "$2" 2>&1 | grep -q "모호한 링크"' _ "$S/check-chapter.sh" "$tmp/v/p/chapter-06-z"
rm -rf "$tmp"

# --- SKILL-003 R14-② 같은 폴더에 그 이름 파일이 있으면 경고하지 않는다 ---
# 옵시디언은 같은 폴더를 먼저 해석한다 — 링크를 담은 노트의 폴더에 그 이름
# 파일이 있으면 vault 전체에 같은 이름이 더 있어도 모호하지 않다.
# chapter-06-z 자신에 04-summary.md 가 있고, chapter-06-z/01-x.md 가 경로
# 없이 [[04-summary]] 를 링크한다 — 같은 이름이 chapter-03-y 에도 있어
# vault 전체 개수는 2 지만, 같은 폴더 자기참조이므로 경고하지 않아야 한다.
tmp=$(mktemp -d)
mkdir -p "$tmp/v/p/chapter-03-y" "$tmp/v/p/chapter-06-z"
echo '## d' > "$tmp/v/_glossary.md"
printf '# a\n' > "$tmp/v/p/chapter-03-y/04-summary.md"
printf '# b\n' > "$tmp/v/p/chapter-06-z/04-summary.md"
printf '# c\n\n[[04-summary]]\n' > "$tmp/v/p/chapter-06-z/01-x.md"
expect 0 "check-chapter: 같은 폴더에 그 이름 파일이 있으면 경고하지 않는다(SKILL-003 R14-②)" -- \
  bash -c '! "$1" "$2" 2>&1 | grep -q "모호한 링크"' _ "$S/check-chapter.sh" "$tmp/v/p/chapter-06-z"
rm -rf "$tmp"

echo "---"; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
