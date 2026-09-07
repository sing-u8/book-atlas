#!/usr/bin/env python3
"""audit-delivery.pages() 회귀 검사 (SKILL-008).

이 볼트의 커버리지 표는 쪽번호와 함께 줄번호를 적는다(`191 7행–192 10행`).
줄번호를 걷어내지 않고 모든 숫자를 뽑으면 마지막 숫자가 끝쪽이 아니라
"끝쪽의 줄번호"라서 (191, 10) 같은 뒤집힌 범위가 나오고, pdftotext 는
그 범위에 대해 오류 없이 빈 출력을 낸다 — 검사가 아무것도 읽지 않았는데
`누락 의심 0건`을 인쇄하고 exit 0 한다. 조용한 실패라 눈으로는 못 잡는다.
"""
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("ad", HERE.parent / "audit-delivery.py")
ad = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ad)

CASES = [
    # (입력, 기대) — 앞 절반은 SKILL-008 이 고치는 것, 뒤 절반은 불변이어야 하는 것
    ("191 7행–192 10행", (191, 192)),   # 양쪽 끝에 줄번호
    ("192 11–29행",      (192, 192)),   # 한 쪽 안에서 줄 범위
    ("173–174 14행",     (173, 174)),   # 끝쪽에만 줄번호
    ("180 17행–182",     (180, 182)),   # 시작쪽에만 줄번호
    ("186 12행–188 20행", (186, 188)),
    ("93 27행–96 11행",  (93, 96)),
    ("82 9–14행",        (82, 82)),
    ("210 24–32행",      (210, 210)),
    ("205 4–19행",       (205, 205)),
    ("36(26행)–39(24행)", (36, 39)),    # 괄호 표기 — 기존 동작 불변
    ("326(중간)–329",     (326, 329)),
    ("8(상단 5~8행)",     (8, 8)),
    ("166–169",          (166, 169)),
    ("152",              (152, 152)),
]

fails = []
for spec_str, want in CASES:
    got = ad.pages(spec_str)
    if got != want:
        fails.append(f"  pages({spec_str!r}) → {got}, 기대 {want}")

# 뒤집힌 범위가 나오면 안 된다 — 나오는 순간 pdftotext 가 조용히 빈 출력을 낸다
for spec_str, _ in CASES:
    got = ad.pages(spec_str)
    if got and got[0] > got[1]:
        fails.append(f"  pages({spec_str!r}) → {got} 는 뒤집힌 범위다")

if fails:
    print("FAIL audit-delivery.pages()")
    print("\n".join(fails))
    sys.exit(1)
print(f"OK  audit-delivery.pages() {len(CASES)}건")
