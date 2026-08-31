#!/usr/bin/env bash
# extract-figure.sh — 책 도표를 PDF에서 추출한다
# usage: extract-figure.sh <pdf> <page> <label> <out-dir>
#   page  = PDF 기준 페이지 번호 (책 페이지 아님)
#   label = 도표 식별자 (예: fig8-3)
# exit: 0 성공 / 1 실패 — 실패 시 재현으로 폴백하라는 안내를 낸다
set -uo pipefail

# check-note.sh/check-note-hook.sh와 같은 이유로 로케일을 C로 고정한다. 책
# 제목에 한글 등 비ASCII 문자가 섞인 PDF 파일명으로 슬러그를 만들 때 tr/sed가
# 호출 측 로케일에 따라 다르게 동작하거나 illegal byte sequence 에러를 내지
# 않도록, 바이트 단위로 예측 가능하게 동작하게 스크립트 자신이 고정한다.
export LC_ALL=C

if [ $# -ne 4 ]; then
  echo "usage: extract-figure.sh <pdf> <page> <label> <out-dir> → 도표를 ASCII/Mermaid로 재현하세요" >&2
  exit 1
fi

PDF="$1"; PAGE="$2"; LABEL="$3"; OUTDIR="$4"

if [ ! -f "$PDF" ]; then
  echo "extract-figure: PDF 없음: $PDF → 도표를 ASCII/Mermaid로 재현하세요" >&2
  exit 1
fi
case "$PAGE" in
  ''|*[!0-9]*) echo "extract-figure: page는 숫자여야 합니다: $PAGE → 도표를 ASCII/Mermaid로 재현하세요" >&2; exit 1 ;;
esac
if ! command -v pdfimages >/dev/null 2>&1; then
  echo "extract-figure: pdfimages 없음. brew install poppler → 도표를 ASCII/Mermaid로 재현하세요" >&2
  exit 1
fi

mkdir -p "$OUTDIR"

slug=$(basename "$PDF" .pdf \
  | tr '[:upper:]' '[:lower:]' \
  | tr ' _' '--' \
  | sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//' \
  | cut -c1-40)

# 제목이 전부 비ASCII(예: 순한글 단행본 제목)면 위 파이프라인이 모든 바이트를
# 걸러내 slug가 비거나 하이픈만 남을 수 있다. 그 경우 원본 파일명의
# 체크섬으로 대체해 항상 사용 가능한 ASCII slug를 보장한다 (같은 PDF는 매번
# 같은 값이 나온다).
if [ -z "$(printf '%s' "$slug" | tr -d '-')" ]; then
  fallback_id=$(basename "$PDF" .pdf | cksum | awk '{print $1}')
  slug="book-${fallback_id}"
fi

target="$OUTDIR/${slug}-p${PAGE}-${LABEL}.png"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

filesize() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

pdfimages -f "$PAGE" -l "$PAGE" -png "$PDF" "$TMP/img" >/dev/null 2>&1 || true

big=""
for f in "$TMP"/img-*.png; do
  [ -f "$f" ] || continue
  if [ -z "$big" ] || [ "$(filesize "$f")" -gt "$(filesize "$big")" ]; then
    big="$f"
  fi
done

# 8KB 미만은 로고·장식 조각일 가능성이 높으므로 버린다
if [ -n "$big" ] && [ "$(filesize "$big")" -gt 8000 ]; then
  cp "$big" "$target"
else
  if ! command -v pdftoppm >/dev/null 2>&1; then
    echo "extract-figure: pdfimages 실패, pdftoppm도 없음 → 도표를 ASCII/Mermaid로 재현하세요" >&2
    exit 1
  fi
  pdftoppm -f "$PAGE" -l "$PAGE" -r 150 -png -singlefile "$PDF" "$TMP/page" >/dev/null 2>&1 || true
  if [ -f "$TMP/page.png" ] && [ "$(filesize "$TMP/page.png")" -gt 8000 ]; then
    cp "$TMP/page.png" "$target"
    echo "extract-figure: 개별 이미지 추출 실패 → 페이지 전체를 렌더했습니다. 필요한 부분만 잘라 쓰세요." >&2
  else
    echo "extract-figure: 추출 실패 → 도표를 ASCII/Mermaid/표로 재현하세요" >&2
    exit 1
  fi
fi

echo "$target"
echo "![[_assets/$(basename "$target")]]"
