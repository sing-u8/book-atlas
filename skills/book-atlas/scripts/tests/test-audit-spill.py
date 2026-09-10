#!/usr/bin/env python3
"""audit-delivery 의 쪽 넘침(spillover) 필터 회귀 검사 (SKILL-010).

커버리지 표의 구간은 `321 7행–322 35행` 처럼 **행까지** 적히는데, 검사는 쪽 단위로만
잘라 읽었다. 그래서 p.321 의 1~6행(앞 절)과 p.322 의 36행 이후(다음 절)가 이 행의
후보로 딸려 들어와, 그 절이 담지 않은 것이 당연한 표제들이 전부 누락 의심으로 남았다.

`line_bounds()` 가 행 범위를 읽고, `candidates(lines, lo, hi)` 가 그 범위 밖 줄을
후보에서 뺀다. **읽을 수 없는 표기는 (None, None) 로 두어 거르지 않는다** — 잘못
거르면 진짜 발견이 사라지지만, 못 거르면 지금까지의 잡음이 남을 뿐이다.
"""
import importlib.util
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("ad", HERE.parent / "audit-delivery.py")
ad = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ad)

BOUNDS = [
    ("321 7행–322 35행", (7, 35)),     # 양쪽 끝에 행번호 — 가장 흔한 꼴
    ("93 27행–96 11행",  (27, 11)),
    ("319 31행–320 5행", (31, 5)),
    ("192 11–29행",      (11, 29)),    # 한 쪽 안에서 행 범위
    ("210 24–32행",      (24, 32)),
    ("173–174 14행",     (None, 14)),  # 끝쪽에만
    ("89 20행–90",       (20, None)),  # 시작쪽에만
    ("180 17행–182",     (17, None)),
    ("36(26행)–39(24행)", (26, 24)),    # 괄호 표기
    ("166–169",          (None, None)),  # 행 표기 없음 — 거르지 않는다
    ("152",              (None, None)),
    ("284(상단)",         (None, None)),  # 숫자 없는 괄호 주석
]

fails = []
for s, want in BOUNDS:
    got = ad.line_bounds(s)
    if got != want:
        fails.append("line_bounds(%r) → %r, 기대 %r" % (s, got, want))

# 한 쪽 안에서 자르기: 1~3행은 앞 절, 4~5행이 이 행, 6행부터 다음 절
page = [
    "Previous Section Heading",   # 1
    "prose",                      # 2
    "",                           # 3
    "Target Section Heading",     # 4
    "prose of the target",        # 5
    "Next Section Heading",       # 6
]
got = [l for _, l, _ in ad.candidates(page, 4, 5)]
if got != ["Target Section Heading"]:
    fails.append("한 쪽 안 자르기 → %r" % (got,))
if len([l for _, l, _ in ad.candidates(page)]) != 3:
    fails.append("경계를 안 주면 전부 남아야 한다 → %r" % ([l for _, l, _ in ad.candidates(page)],))

# 경계가 한쪽만 주어진 경우
if [l for _, l, _ in ad.candidates(page, 4, None)] != ["Target Section Heading", "Next Section Heading"]:
    fails.append("시작 경계만 주었을 때가 틀렸다")
if [l for _, l, _ in ad.candidates(page, None, 4)] != ["Previous Section Heading", "Target Section Heading"]:
    fails.append("끝 경계만 주었을 때가 틀렸다")

# extract_pages 는 쪽별로 나눠 주어야 한다(줄번호를 쪽 안에서 세기 위해)
sample = "a\nb\fc\nd\n\f"
if ad.split_pages(sample) != [["a", "b"], ["c", "d", ""]]:
    fails.append("split_pages → %r" % (ad.split_pages(sample),))

if fails:
    for f in fails:
        print("FAIL", f)
    raise SystemExit(1)
print("test-audit-spill: %d 케이스 통과" % (len(BOUNDS) + 5))
