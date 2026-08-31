#!/usr/bin/env bash
# verify-offset.sh — 책쪽 ↔ PDF쪽 오프셋을 쪽번호 왕복 대조로 검산한다
# usage: verify-offset.sh <pdf> <book-page> <offset>
#   목차가 말하는 book-page 를 offset 으로 PDF 쪽으로 바꾸고, 그 페이지가
#   실제로 book-page 를 인쇄하는지 확인한다. 1쪽 어긋남도 잡힌다.
# exit: 0 일치 / 2 불일치(또는 이 페이지로는 검증 불가) / 1 사용법·입력 오류
# bash 3.2 호환 — 배열 사용 금지
set -uo pipefail
export LC_ALL=C

# folio_matches <candidate-lines> <book-page>
#   인쇄된 쪽번호는 그냥 그 숫자가 줄 어딘가에 있는 게 아니라, 다음 세
#   "구조적 위치" 중 하나에만 나타난다 (fix round 1 — 리뷰에서 책p134를
#   오프셋23으로 잘못 통과시킨 원인은 위치를 안 보고 숫자 존재만 봤기 때문):
#     1) 줄 전체가 그 숫자 하나뿐        "              113"
#     2) 숫자로 시작해 뒤에 |가 옴        "114   |   Chapter 3: ..."
#     3) |가 있고 줄이 그 숫자로 끝남     "... Engineering   |    7"
#   본문 속 상호참조("... on page 134 discusses ...")나 각주 번호로 시작하는
#   줄("6 This is similar to ...")은 이 세 형태 중 어느 것도 아니므로
#   걸러진다. 부분 문자열(예: 쪽 11 vs "114 | ...")도 각 형태가 숫자
#   앞뒤를 줄 시작·끝·|로 고정하므로 여전히 걸러진다.
folio_matches() {
  _fm_lines="$1"; _fm_bp="$2"
  printf '%s\n' "$_fm_lines" | grep -qE \
    '^[[:space:]]*'"$_fm_bp"'[[:space:]]*$|^[[:space:]]*'"$_fm_bp"'[[:space:]]*[|]|[|][[:space:]]*'"$_fm_bp"'[[:space:]]*$'
}

verify_offset_main() {
  if [ $# -ne 3 ]; then
    echo "usage: verify-offset.sh <pdf> <book-page> <offset>" >&2
    return 1
  fi

  PDF="$1"; BOOKP="$2"; OFF="$3"

  if [ ! -f "$PDF" ]; then
    echo "verify-offset: PDF 없음: $PDF" >&2
    return 1
  fi

  case "$BOOKP" in
    ''|*[!0-9]*) echo "verify-offset: book-page 는 숫자여야 합니다: $BOOKP" >&2; return 1 ;;
  esac

  case "$OFF" in
    -*) offdigits="${OFF#-}" ;;
    *)  offdigits="$OFF" ;;
  esac
  case "$offdigits" in
    ''|*[!0-9]*) echo "verify-offset: offset 은 정수여야 합니다: $OFF" >&2; return 1 ;;
  esac

  if ! command -v pdftotext >/dev/null 2>&1; then
    echo "verify-offset: pdftotext 없음. brew install poppler" >&2
    return 1
  fi

  PDFP=$((BOOKP + OFF))
  if [ "$PDFP" -lt 1 ]; then
    echo "verify-offset: 계산된 PDF 쪽이 1 미만입니다 ($PDFP). offset 을 확인하세요." >&2
    return 1
  fi

  page=$(pdftotext -layout -f "$PDFP" -l "$PDFP" "$PDF" - 2>/dev/null)

  # 쪽번호는 머리말·꼬리말에 인쇄된다. 빈 줄을 뺀 뒤 처음 2줄과 마지막 2줄만 본다.
  # 공백만 있는지는 원본 $page 가 아니라 이 nb(빈 줄 제거 후)로 판정해야
  # 한다 — pdftotext 는 완전히 빈 페이지에서도 폼피드(\f) 한 글자를 내보내는
  # 경우가 있어("$page" 길이가 1) 원본만 보면 -z 검사를 통과해버린다. 이
  # \f 는 [[:space:]] 이므로 아래 grep -v 로 걸러지고 nb 가 진짜 비어야
  # 정확히 "인쇄된 글자 없음"이 된다 (fix round 1 — 책p158/210 같은 출판사
  # 공백 페이지가 정확한 offset에서도 거짓 실패로 보고되던 문제).
  nb=$(printf '%s\n' "$page" | grep -vE '^[[:space:]]*$')
  if [ -z "$nb" ]; then
    # 빈 페이지는 "불일치"와 다른 실패다 — offset 이 틀렸다는 증거가
    # 전혀 없다(그냥 이 book-page 로는 검증 자체가 불가능하다는 뜻). 그런데도
    # exit 코드는 여전히 2 다 — 계약이 0/2/1 세 값으로 고정돼 있어 세 번째
    # 코드를 새로 만들 수 없기 때문. 그래서 메시지로 두 실패를 분명히
    # 구분하고, 다른 쪽으로 재표본하라고 명시로 안내한다.
    echo "verify-offset: 빈 페이지 — PDFp$PDFP 에서 텍스트를 추출하지 못했습니다." >&2
    echo "  스캔본이거나, 페이지 범위 밖이거나, 장 시작 전 출판사가 넣은 공백 페이지일 수 있습니다." >&2
    echo "  이 결과는 offset 이 틀렸다는 증거가 아닙니다 — 이 book-page 로는 검증할 수 없습니다. 다른 book-page 로 다시 표본을 뽑아 확인하세요." >&2
    return 2
  fi

  edges=$(printf '%s\n' "$nb" | head -2; printf '%s\n' "$nb" | tail -2)

  if folio_matches "$edges" "$BOOKP"; then
    echo "verify-offset: OK   책p$BOOKP = PDFp$PDFP — 그 페이지가 $BOOKP 을 인쇄함"
    return 0
  fi

  echo "verify-offset: FAIL 책p$BOOKP → PDFp$PDFP 로 계산했으나 그 페이지가 $BOOKP 을 인쇄하지 않습니다." >&2
  echo "  머리말·꼬리말 후보:" >&2
  printf '%s\n' "$edges" | sed 's/^/    /' >&2
  echo "  오프셋이 틀렸거나, 이 구간의 오프셋이 다르거나, 쪽번호 없는 페이지입니다." >&2
  return 2
}

# 소스로 불러왔을 때는(테스트가 folio_matches 만 검증할 때) 메인을 실행하지
# 않는다 — 스크립트로 직접 실행됐을 때만 $0 과 $BASH_SOURCE 가 같다.
if [ "${BASH_SOURCE:-$0}" = "$0" ]; then
  verify_offset_main "$@"
  exit $?
fi
