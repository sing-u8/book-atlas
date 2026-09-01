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

echo "---"; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
