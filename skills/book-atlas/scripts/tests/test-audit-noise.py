#!/usr/bin/env python3
"""audit-delivery.candidates() 잡음 필터 회귀 검사 (SKILL-009).

`candidates()` 는 표제·콜아웃·캡션만 후보로 올린다고 계약한다. 그런데 두 종류의
쪽 furniture 가 그 셋 중 하나로 잘못 분류돼 후보에 섞인다.

1. 러닝 헤더·푸터 — `230   |   Chapter 10: ...`(좌면)와
   `Multi-LLM Architectures   |   323`(우면). 우면 형태는 오른쪽 정렬이라
   들여쓰기 15 이상이 되어 **콜아웃**으로 잡힌다. `CHAPTER 8`·`PART III`
   같은 장·부 표지도 마찬가지다.
2. 목록·코드를 여는 산문 리드인 — `Output:`·`Here is an example:`·
   `Two important metrics in speculative decoding are:`. 들여쓰기 0·마침표 없음·
   대문자 시작·7단어 이하라 **표제** 조건을 그대로 통과한다.

둘 다 노트가 "언급"할 대상이 아니라서 전부 누락 의심으로 남는다. 실제로 8~13장
재검수에서 잔여 76건 중 진짜 누락은 0건이었고, 그 76건의 대부분이 이 둘이었다.
"""
import importlib.util
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("ad", HERE.parent / "audit-delivery.py")
ad = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ad)

# 들여쓰기가 의미를 갖는 검사라 원문 렌더를 그대로 흉내낸다.
DROP = [
    ("좌면 러닝 푸터",     "230   |   Chapter 10: Interfacing LLMs with External Tools"),
    ("좌면 러닝 푸터(공백차)", "192   |    Chapter 8: Alignment Training and Reasoning"),
    ("우면 러닝 헤더",     "                              Multi-LLM Architectures   |   323"),
    ("우면 러닝 헤더2",    "                              Mitigating Hallucinations   |   197"),
    ("챕터 표지",         "                                                      CHAPTER 13"),
    ("파트 표지",         "                                                         PART III"),
    ("리드인 — 짧은 것",   "Output:"),
    ("리드인 — 예시",     "Here is an example:"),
    ("리드인 — 목록 여는", "Two important metrics in speculative decoding are:"),
    ("리드인 — 프롬프트 안", "Sentiment:"),
]

KEEP = [
    ("절 표제",           "Multi-LLM Architectures"),
    ("절 표제2",          "Techniques for Reducing Compute"),
    ("정의 목록 항목",     "Token acceptance rate"),
    ("정의 목록 항목2",    "Supervised fine-tuning"),
    ("캡션",             "Figure 13-1. LLM cascades"),
    ("콜아웃(TIP)",       "                Older GPUs like the NVIDIA T4 do not support BF16."),
    ("콜아웃(경고)",       "                Beware of asking the LLM to verify its own work in any form!"),
]

fails = []
for label, line in DROP:
    got = ad.candidates([line])
    if got:
        fails.append("버려야 하는데 후보로 올라옴 [%s] %r → %r" % (label, line.strip(), got))
for label, line in KEEP:
    got = ad.candidates([line])
    if not got:
        fails.append("남겨야 하는데 버려짐 [%s] %r" % (label, line.strip()))

# 러닝 헤더가 인접한 진짜 콜아웃과 병합돼 탐침을 오염시키지 않아야 한다.
block = [
    "                Adding more verifiers can drastically increase system latency.",
    "                Thus, their inclusion has to be balanced with accuracy needs.",
    "251   |   Chapter 10: Interfacing LLMs with External Tools",
]
got = ad.candidates(block)
if len(got) != 1:
    fails.append("러닝 푸터가 콜아웃과 분리되지 않음 → %r" % (got,))
elif any("Chapter" in p or p == "251" for p in got[0][2]):
    fails.append("러닝 푸터의 토큰이 콜아웃 탐침을 오염시킴 → %r" % (got[0][2],))

if fails:
    for f in fails:
        print("FAIL", f)
    raise SystemExit(1)
print("test-audit-noise: %d 케이스 통과" % (len(DROP) + len(KEEP) + 1))
