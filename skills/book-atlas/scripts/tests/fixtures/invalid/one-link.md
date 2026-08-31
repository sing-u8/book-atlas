---
book: sample-book
chapter: chapter-01-intro
section: "1.1"
title: "What Is Retrieval"
pages: "책 p.2–4 / PDF p.10–12"
concepts: [retrieval]
status: done
---

# 1.1 What Is Retrieval

## 한눈에 보기

| 질문 | 핵심 답 |
|---|---|
| 검색이 왜 생성보다 먼저 오나? | 모델이 모르는 문서를 먼저 찾아야 답할 재료가 생기기 때문 |

## 왜 이 절인가

사내 위키 1만 페이지에서 휴가 규정을 찾는다고 하자. 질문을 모델에 그냥 던지면
위키를 학습한 적 없는 모델은 지어내기 시작한다 — 그래서 관련 문서를 먼저 찾아
오는 **[[retrieval]]**(= 질문과 관련된 문서를 먼저 찾아오는 단계)이 필요해진다.

## 본문 정리

### 검색이 먼저다

책은 사내 위키 예시를 든다. 질문을 받으면 먼저 관련 문서를 찾는다 — 모델이
학습하지 않은 정보를 답에 쓰기 위해서다. 찾은 문서는 **[[context]]**(= 모델에
함께 넣어 주는 참고 자료)로 붙는다.

```mermaid
flowchart LR
    Q[질문] --> R[retrieval] --> C[context] --> A[답변]
```

## 개념

| 개념 | 한 줄 정의 | 링크 |
|---|---|---|
| retrieval | 질문과 관련된 문서를 먼저 찾아오는 단계 | [[_glossary#retrieval]] |
| context | 모델에 함께 넣어 주는 참고 자료 | [[_glossary#context]] |

## 연결

- [[retrieval]] — 여기서 찾아온 문서를 다음 절이 순위 매긴다

## 스스로 확인

- retrieval 없이 모델만으로 답할 때 무엇이 먼저 깨지나?
- context 가 커질수록 무엇이 나빠지나?

<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->

## 내 메모
