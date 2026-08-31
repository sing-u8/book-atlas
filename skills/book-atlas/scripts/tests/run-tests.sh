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

echo "---"; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
