# book-atlas 설계 스펙

> 원서(PDF) 한 권을 목차 구조 그대로 충실하게 정리하고, 챕터·절·개념의 연결을
> three.js 기반 3D 그래프로 시각화하는 Claude Code 스킬. deep-tutor 의 책 모드
> 자산(목차 파이프라인·작성 규칙·용어집·검증 게이트)을 이식하되, 인출 훈련이 아니라
> **정리와 시각화**를 본체로 삼는다.
>
> 작성일: 2026-08-31 · 승인된 브레인스토밍 결정을 기록한 정본.

---

## 1. 목표와 비목표

### 목표

1. **목차 기준 정리** — PDF 원서의 목차를 추출·검증하고, 그 구조를 미러링하는
   노트 저장소를 만든다.
2. **충실한 반영** — 책의 서술을 재구성해 정리하되, 원문 쪽 범위 ↔ 노트 대응표로
   누락을 기계 검출한다.
3. **개념 정의 동반** — 본문에 등장하는 개념은 그 자리에서 정의하고, 책 전체
   단일 용어집에 정본을 둔다. "섞이는 말" 필드로 혼동 쌍을 명시한다.
4. **연결 그래프** — 책→챕터→절 노트→개념 3층 구조와 개념 간 관계를
   three.js 기반 동적 포스 그래프 HTML 로 보여준다. 노드 클릭 시 Obsidian 에서
   해당 노트가 열린다.
5. **가벼운 확인** — 노트마다 답 없는 "스스로 확인" 씨앗 질문을 두고, 사용자가
   요청하면 가볍게 던진다. 본격 인출 훈련은 하지 않는다.

### 비목표

- **인출 훈련 체계** — 꼬리질문 사다리, gap 추적, Feynman, Regeneration 등은
  deep-tutor 의 몫이다. 이 스킬은 이식하지 않는다.
- **deep-tutor 저장소 마이그레이션** — 기존 `*-notes/` 저장소를 변환하지 않는다.
- **Codex 호스트 지원** — Claude Code 전용. deep-tutor 의 host-compatibility
  레이어는 이식하지 않는다.
- **스캔본 OCR** — 텍스트 추출이 안 되는 PDF 는 중단하고 사용자에게 알린다.
- **다중 소스** — 저장소 하나 = 책 한 권. 여러 책은 저장소를 나눈다.
- **Obsidian 플러그인** — 그래프는 독립 HTML 파일이다. Obsidian 내장 그래프는
  위키링크 컨벤션 덕에 덤으로 작동할 뿐, 의존 대상이 아니다.

### 브레인스토밍에서 확정된 결정

| 결정 | 선택 | 기각된 대안 |
|---|---|---|
| 스킬 범위 | 정리 중심 + 가벼운 확인 | 정리·그래프 전용 / 풀 사이클(인출 포함) |
| 저장소 스키마 | 독자 설계 (Obsidian 호환 유지) | deep-tutor 책 모드 호환 / 절충 확장 |
| 그래프 노드 모델 | 3층(책→챕터→절 노트→개념) + 레이어 토글 | 챕터↔개념 2층 / 파일=노드 |
| 그래프 파이프라인 | 빌드 스크립트(노트가 정본, 스크립트가 재생성) | 모델 직접 관리 / Obsidian 그래프 의존 |
| 이름 | `book-atlas` | book-study / book-tutor |
| deep-tutor 이식 | #1~#9 전부 (아래 §10 이식 지도) | — (#10 인출 체계만 제외) |

---

## 2. 학습 저장소(vault) 구조

책 한 권 = 저장소 하나. 저장소 이름은 `{book-slug}-atlas/` — 접미사가 deep-tutor 의
`*-notes/` 라우팅 글롭과 겹치지 않으므로 두 스킬이 같은 프로젝트 루트에 공존해도
서로를 오인하지 않는다.

```
{book-slug}-atlas/                      # 예: ai-engineering-atlas/
├── _global/
│   ├── config.md                       # 언어 · vault명 · 소스 경로 · 진행 위치 표
│   └── source-manifest.md              # 목차 트리·쪽 오프셋의 유일한 정본
├── _glossary.md                        # 책 전체 단일 용어집 = 개념 노드의 정본
├── _assets/                            # 추출 도표 (파일명에 book-slug·PDF쪽 포함 → 루트 하나로 충분)
├── graph/
│   ├── graph.html                      # 뷰어 — 온보딩 때 스킬 assets 에서 복사, 이후 불변
│   ├── graph-data.js                   # build-graph.py 산출물 — 손 편집 금지
│   └── lib/
│       └── 3d-force-graph.min.js       # vendored UMD 번들 (three.js 포함, ~1.2MB)
├── [part-N-{slug}/]                    # 책에 Part 가 있을 때만 — 없는 계층을 지어내지 않는다
│   └── chapter-NN-{slug}/              # NN = 0패딩 2자리 (chapter-01, chapter-10 — 사전순 정렬 보장)
│       ├── _chapter.md                 # 챕터 개요 (스킬 소유, §5)
│       ├── _coverage.md                # 원문 커버리지 대응표 (§6)
│       └── NN-{slug}.md                # 절 노트. NN = 챕터 안 절(section) 순번, 0패딩 2자리.
                                        # 하위 항목(목차의 subsection 또는 §7 분할)은 NNa-, NNb-
```

- **deep-tutor 와 다른 점 1 — 용어집이 책 전체 하나.** 같은 개념이 여러 챕터에
  걸쳐 등장하는 것 자체가 그래프의 엣지가 되므로, 정의가 챕터마다 중복되면 안 된다.
- **deep-tutor 와 다른 점 2 — session-log 없음.** 진행은 `config.md` 진행 표 +
  노트 frontmatter `status` 로 충분하고, 그래프가 그것을 읽어 진행 대시보드
  역할을 겸한다.
- 챕터 디렉터리는 온보딩 때 **전 챕터를 미리 생성**하고, 내부 파일(`_chapter.md`
  `_coverage.md` 노트)은 그 챕터 정리를 시작할 때 만든다.

### `_global/config.md` 필드

```markdown
# Config

## 기본
- book_slug: ai-engineering
- book_title: AI Engineering
- language: ko                # 대화·파일 본문 언어
- vault_name: MyVault         # Obsidian vault 이름 — 그래프 클릭 URI 에 주입
- source_pdf: ../AI-Engineering.pdf

## 진행 위치
| 챕터 | 상태 | 다음 |
|---|---|---|
| chapter-01-... | 완료 | — |
| chapter-02-... | 진행 중 | 03-instruction-data |
```

`vault_name` 은 온보딩 때 사용자에게 직접 묻는다(자동 추정하지 않는다 — 틀리면
그래프의 모든 클릭이 조용히 실패한다). 비워 두면 뷰어는 클릭 시 정보 패널만 연다.

### `_global/source-manifest.md`

deep-tutor `book-mode.md` §7 의 정본 원칙을 그대로 이식한다:

- 목차 트리 표: `| 계층 | 번호 | 제목 | 슬러그 | 시작 책쪽 | 상태 |` —
  상태는 `파싱됨` / `사용자수정` / `미파싱`.
- 쪽 오프셋 구간 표: `| 구간 | 오프셋 | 검산 |`.
- 스킬이 쓰지만 최종 권한은 사용자에게 있다. 재파싱 결과로 조용히 덮어쓰지 않고,
  `사용자수정` 행은 재파싱 제안 대상에서 우선 제외한다.

---

## 3. 절 노트 스키마

### frontmatter — 그래프 빌더가 파싱하는 계약 (7키 전부 필수)

```yaml
---
book: ai-engineering                                  # config 의 book_slug 와 일치
chapter: chapter-01-introduction-to-building-ai-applications   # 챕터 디렉터리명 (part- 접두 제외, 마지막 한 칸)
section: "1.1"                                        # 목차 번호 (사람용)
title: "The Rise of AI Engineering"                   # 원문 제목
pages: "책 p.2–8 / PDF p.26–32"                       # 사람용 표기 — 빌더는 존재만 확인
concepts: [ai-engineering, foundation-model]          # 이 절이 '중요하게 다루는' 개념 슬러그 → covers 엣지
status: draft                                         # draft | done
---
```

`concepts:` 와 본문 `[[링크]]` 는 역할이 다르다 — 전자는 "중요하게 다룸"(굵은
엣지), 후자는 "언급"(얇은 엣지). `concepts` 의 슬러그는 `_glossary.md` 등재
항목이어야 한다(check-note 가 대조).

### 필수 H2 6개 — 기계 검사 리터럴, 로컬라이즈하지 않는다

| 섹션 | 내용 | 이식 근거 |
|---|---|---|
| `## 한눈에 보기` | 질문 → 핵심 답 표 1개. 항목 나열이 아니라 이 절이 답하는 질문을 세운다 | 규칙 9 |
| `## 왜 이 절인가` | 정의로 열지 않는다 — 구체적 장면·코드·숫자에서 출발해 이 절의 문제의식으로 | 규칙 1 |
| `## 본문 정리` | 원문 하위 제목을 H3 로 미러링하며 재구성 정리. 단계마다 "— …하기 위해서다", 근거 표시, 장문 복사 금지 | 규칙 5·7·10·11·12 |
| `## 개념` | 이 절에서 처음 등장한 개념 표: 개념 · 한 줄 정의 · `[[_glossary#슬러그]]` 링크 | 규칙 2·3 |
| `## 연결` | `- [[대상]] — 관계의 성격 한 줄` 형식 ≥2. 대상은 다른 노트 또는 개념 | deep-tutor 규칙 3 |
| `## 스스로 확인` | 답 없는 씨앗 질문 2~3개 | 범위 결정(가벼운 확인) |

- **도표는 섹션 강제가 아니라 존재 검사** — 노트 어딘가에 도표 ≥1
  (mermaid/text 코드펜스 또는 `![[_assets/...]]` 임베드). 정리 중심에서는 도표가
  본문 정리의 해당 위치에 인라인으로 있는 게 자연스럽기 때문이다.
- 노트 맨 아래에 구분자 + 사용자 영역:

```markdown
<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->

## 내 메모
```

  스킬은 이 아래를 **덮어쓰거나 지우지 않는다**(추가 기록도 하지 않는다 — 순수
  사용자 자리다. deep-tutor 와 달리 스킬이 받아 적을 인출 시도가 없으므로 규칙이
  더 단순하다).

### 본문 인라인 용어 규칙

처음 등장하는 전문어는 `**[[슬러그]]**(= 한 줄 풀이)` 형태로 링크+풀이를 함께
붙이고 용어집에 등재한다. 셋 중 하나라도 빠지면 "무설명 용어"다. 슬러그는
용어집 `##` 제목의 첫 토큰과 정확히 일치해야 한다(공백 금지 — 하이픈 연결).

---

## 4. 작성 규칙 12개 (deep-tutor note-authoring 각색)

규칙 본문·위반/교정 예시 쌍은 `references/note-rules.md` 로 이식하되, 섹션 참조를
새 스키마(§3)에 맞게 고친다. 규칙 자체는 동일하다:

1. 정의로 열지 않는다 — 첫 문단은 구체적 장면·코드·숫자 (`## 왜 이 절인가`)
2. 무설명 용어 0 — 인라인 한 줄 + 용어집 등재 + `[[링크]]`
3. 용어로 용어를 설명하지 않는다 — 최소 한 번 비전문 언어로 착지
4. 비유 최소 1개 + 비유가 깨지는 지점 한 줄
5. 메커니즘 각 단계마다 "왜 이 단계가 필요한가"
6. 도표 최소 1개 (위치 자유 — 존재 검사)
7. 책 원문을 길게 옮기지 않는다 — 재구성한다
8. 이름의 유래를 풀어준다
9. `한눈에 보기` 는 질문 → 답 표
10. 메커니즘 각 단계는 "— …하기 위해서다"로 끝난다, 예외 없이
11. 원문 근거를 명시한다 — "책은 ~를 예로 든다"
12. 책과 공식 문서가 다르면 뭉개지 않고 둘 다 적는다

**완료 게이트**: 노트를 `status: done` 으로 바꾸기 전에 12개 규칙 체크리스트를
전수 확인(용어는 "확인했는가"가 아니라 **전부 나열 후 용어집과 하나씩 대조**)하고,
`check-note.sh` 를 실행한다. 규칙 9~12 는 기계 검사가 불가능한 모델 판단 항목임을
게이트 문서에 명시한다.

---

## 5. 챕터 개요 `_chapter.md` (스킬 소유)

deep-tutor 챕터 `_map.md` 의 정리 중심 버전. 필수 요소 5개:

1. **장의 논지 한 문단** — "이 장은 기능 목록이 아니라 ~라는 하나의 흐름을
   이해하는 장이다"
2. **읽는 순서 mermaid flowchart** — 노트 사이 의존 순서
3. **노트 → 원문에서 답하는 질문 표**
4. **`[[_coverage]]` 링크** — 누락 추적은 coverage 가 담당
5. **구분자 + `## 내 메모`** — §3 과 동일한 사용자 영역

인출용 "재구성 대조" 절은 두지 않는다. 챕터 정리를 시작할 때 뼈대(1·2·3 은
비어 있을 수 있음)를 만들고, 챕터 완결 시점에 1~3 을 완성한다.

---

## 6. 커버리지 `_coverage.md`

deep-tutor 스키마 그대로 이식. 챕터 정리 시작 시 **왼쪽 세 열을 먼저 채운다**.

```markdown
# Chapter NN 원문 커버리지

## 1. 원문 절 → 노트 매핑
| 책 쪽 | PDF 쪽 | 원문 절 | 정리 노트 | 상태 |
|---|---|---|---|---|
| 2–8 | 26–32 | The Rise of AI Engineering | [[01-the-rise-of-ai-engineering]] | 반영 |

## 2. 코드·예제 커버리지
| 원문 예제 | 노트 | 설명 보강 |
|---|---|---|
```

상태 값: `반영` / `부분` / `미반영` — `부분`·`미반영` 은 사유가 함께 있어야
check-chapter 를 통과한다. 병합된 항목(§7)은 행을 지우지 않고 정리 노트 칸이
부모 노트를 가리킨다.

---

## 7. 분할·병합 규칙 (deep-tutor book-mode §9 이식)

적용 시점: `_coverage.md` 표 1 의 왼쪽 세 열을 채운 **직후, 노트를 하나라도
쓰기 전**. 어느 스크립트도 검사하지 않는 모델 판단 규칙이므로 시점을 절차에
못박는다.

목차에 이미 subsection 으로 나열된 항목은 그 자체로 최하위 항목이다 — 이 절차
없이 곧바로 `NNa-` 노트가 되고, 그 부모 section 노트는 아래 분할의 부모 노트
규칙(껍데기 금지)을 그대로 따른다. 아래 두 규칙은 그것과 다른 경우, 즉 목차
최하위 항목 자체가 너무 크거나 얇을 때 스킬이 새로 쪼개거나 합치는 것이다.

- **분할**: 목차에 없는 자체 하위 제목 보유 → `NNa-` `NNb-` 로 쪼갠다. 부모
  노트는 껍데기 금지 — 규칙 1 준수, "왜 이 갈래인가" 설명, 자식 링크는 그
  설명 안에서 등장, 게이트 그대로 통과. 원문 범위는 자동 트리거가 아니라
  점검 신호다 — 책마다 절 길이 분포의 상위 5% 초과·하위 제목 없음이면
  `_coverage.md`에 판단 근거를 남긴다(상세: `toc-pipeline.md` §9).
- **병합** (둘 다): 원문 범위 2책쪽 이하 / 그 항목만의 도표·독립 메커니즘 없음
  → 부모 절 노트의 `### {원문 제목}` H3 절로 흡수. 근거: deep-tutor 실측에서
  1책쪽짜리 항목의 노트/원문 배율이 2.4~2.6배로 부풀었다(스키마 바닥 비용).
- 판단이 애매하면 독립 노트로 둔다 — 병합은 되돌리기 쉽지만 잘못 병합해 내용을
  잃으면 더 비싸다.

---

## 8. 용어집 `_glossary.md`

```markdown
# 용어집

## foundation-model (foundation model)
정의 2~4문장 — 최소 한 번은 비전문 언어로 착지한다.
- 처음 나온 곳: [[01-the-rise-of-ai-engineering]]
- 섞이는 말: [[large-language-model]] — LLM 은 언어 전용, FM 은 멀티모달 포함
```

- 항목 제목: `## 슬러그 (원어)` — 원어 없으면 `## 슬러그`. 슬러그에 공백 금지.
- **중복 정의 금지** — 같은 용어를 두 번 등재하지 않는다. 다른 노트에서 재등장하면
  링크만 건다.
- `섞이는 말` 은 선택 필드지만, 있으면 그래프의 `related` 엣지가 된다.
- 정의 첫 줄(120자 절단)은 그래프 뷰어의 개념 노드 정보 패널에 표시된다(빌더가 추출).

---

## 9. 그래프

### 9.1 데이터 계약 — `graph/graph-data.js`

`build-graph.py` 가 저장소를 스캔해 생성한다. JSON 이 아니라 `.js` 인 이유:
`file://` 로 연 HTML 은 로컬 JSON `fetch` 가 CORS 에 막히지만 `<script src>` 는
통과한다.

```js
window.ATLAS_DATA = {
  book: { slug: "ai-engineering", title: "AI Engineering", vault: "MyVault" },
  generated: "2026-08-31T12:00:00",
  nodes: [
    // type: "book" | "chapter" | "note" | "concept"
    { id: "book:ai-engineering",  type: "book",    label: "AI Engineering" },
    { id: "chapter:chapter-01-…", type: "chapter", label: "1. Introduction…",
      path: "chapter-01-…/_chapter.md", progress: { done: 3, total: 5 } },
    { id: "note:chapter-01-…/01-the-rise…", type: "note", label: "1.1 The Rise…",
      path: "chapter-01-…/01-the-rise….md", status: "done" },
    { id: "concept:foundation-model", type: "concept", label: "foundation-model",
      def: "정의 첫 줄(120자 절단)" }
  ],
  links: [
    // type 의미:
    //  toc       book→chapter, chapter→note  (목차 계층 — 그래프의 뼈대)
    //  covers    note→concept  (frontmatter concepts — 굵은 엣지)
    //  mentions  note→concept  (본문 [[슬러그]] 링크, ## 연결의 개념 항목 — 얇은 엣지)
    //  related   concept↔concept  (용어집 "섞이는 말")
    //  note-link note↔note  (## 연결의 노트 항목)
    { source: "chapter:chapter-01-…", target: "note:chapter-01-…/01-the-rise…", type: "toc" }
  ]
};
```

- 노드 `size` 는 뷰어가 차수(degree)로 계산한다 — 빌더는 넣지 않는다.
- 같은 (source, target, type) 엣지는 중복 제거한다. covers 가 있으면 같은 쌍의
  mentions 는 내보내지 않는다.
- **챕터 노드는 노트가 없어도 manifest 에서 전부 생성**한다 — 온보딩 직후부터
  그래프가 목차 뼈대를 보여주고, 정리가 진행될수록 노트·개념이 자라난다.

### 9.2 `scripts/build-graph.py`

- 실행: `python3 build-graph.py <vault-root>` (인자 생략 시 CWD). **python3 표준
  라이브러리만** — pip 의존 금지.
- 파싱 대상:
  - `source-manifest.md` → book·chapter 노드, toc 엣지
  - 절 노트 frontmatter → note 노드, covers 엣지. YAML 전체 파서가 아니라
    이 스키마의 부분집합(문자열·인라인 리스트)만 정규식으로 읽는다.
  - 절 노트 본문 → mentions·note-link 엣지. **코드펜스 안쪽을 먼저 제거**한 뒤
    위키링크를 추출한다(mermaid 의 `id[[Label]]` 문법 충돌 — deep-tutor 의 교훈).
    `[[_` 로 시작하는 링크는 내부 파일 링크로 보고 건너뛰되,
    `[[_glossary#슬러그]]` 는 개념 참조로 해석한다.
  - `_glossary.md` → concept 노드(def = 정의 첫 문장), related 엣지
- 부수 검증 — **stderr 경고, exit 0 유지** (check 스크립트가 게이트, 빌더는
  리포터):
  - 용어집에 없는 개념 참조 (`concepts:` 항목 포함)
  - `_coverage.md` 가 참조하는 노트가 실제로 없음 — 스코프는 coverage 뿐이다
    (노트 본문의 미해결 `[[링크]]` 는 위 "용어집에 없는 개념 참조" 경로로 잡힌다)
  - `_coverage.md` 에 등장하지 않는 노트
  - 어느 노트도 참조하지 않는 용어집 항목
- exit 1: vault 루트가 아니거나(`_global/config.md` 없음) 출력 불가.

### 9.3 `assets/graph.html` 뷰어

- 라이브러리: `graph/lib/3d-force-graph.min.js` — vasturiano 3d-force-graph 의
  **자체완결 UMD 번들**(three.js 포함, ~1.2MB, MIT). 스킬 저장소에 vendored 로
  동봉하고 온보딩 때 vault 로 복사한다. CDN 참조 없음 — 오프라인·영구 동작.
  (구현 시 1회 다운로드해 커밋한다: `unpkg.com/3d-force-graph/dist/3d-force-graph.min.js`.)
- 기능:
  - 타입별 노드 색 (book/chapter/note/concept 4색) + 다크 테마, 범례
  - 노드 크기 = 차수 비례, `status: draft` 노트는 반투명 — 진행 대시보드 겸용
  - **레이어 토글**: 개념 레이어 / 목차 레이어(book·chapter·note) 체크박스 +
    엣지 타입별(covers/mentions/related/toc/note-link) 토글
  - **호버**: 라벨 + 이웃 하이라이트, 나머지 dim (Obsidian 그래프 뷰 방식)
  - **검색창**: 이름 부분일치 **하이라이트**(첫 매치 + 이웃) + 카메라 이동 —
    필터가 아니다(매치 안 된 노드도 사라지지 않고 회색으로 남는다)
  - **클릭**: `path` 있는 노드 → `obsidian://open?vault={vault}&file={path}` 로
    이동(URL 인코딩). 개념 노드 → `_glossary` 를 연다. `vault` 가 비어 있으면
    화면 안 정보 패널만 연다(개념 노드는 `def` 표시).
  - UI 라벨은 한국어.
- `graph.html` 은 불변 — 데이터만 재생성하고 브라우저 새로고침이 곧 갱신이다.

---

## 10. deep-tutor 이식 지도

| 원본 (deep-tutor) | book-atlas 목적지 | 방식 |
|---|---|---|
| book-mode.md §2–8 (목차 추출·계층 판정 5규칙·오프셋 검산·실패 분류 6종·부분 실패·정본 원칙·디렉터리 생성) | `references/toc-pipeline.md` | **이식** — 개념 모드 폴백 제거(§11 참고), 저장소 이름·경로만 치환 |
| book-mode.md §9 (분할·병합) | `references/toc-pipeline.md` 내 절 | **이식** |
| note-authoring.md (규칙 12 + 완료 게이트 + 용어집 운영 + 저작권) | `references/note-rules.md` | **각색** — 섹션 참조를 새 스키마로, 인출(2·3단계) 언급 제거 |
| figures.md (재현/추출 판단 3질문 · Mermaid 골격 7종 · pdftotext -layout) | `references/figures.md` | **이식** — 경로·게이트 언급만 치환 |
| templates.md | `references/templates.md` | **재작성** — 새 스키마 전체 (config·manifest·노트·_chapter·_coverage·_glossary) |
| verify-offset.sh | `scripts/verify-offset.sh` | **이식** (수정 없음) |
| extract-figure.sh | `scripts/extract-figure.sh` | **이식** (수정 없음) |
| check-note.sh | `scripts/check-note.sh` | **재작성** — frontmatter 7키 · H2 6개 · 도표 존재 · 연결 ≥2 · 용어 대조 · 코드펜스 짝수 · 구분자 |
| check-chapter.sh | `scripts/check-chapter.sh` | **재작성** — 필수 파일 · 참조 노트 존재 · 전 노트 게이트 · 미해결 상태 · 고아 노트 |
| check-note-hook.sh | `scripts/check-note-hook.sh` | **각색** — `*-atlas/` 노트 경로 매칭, Claude Code 전용 |
| scripts/tests | `scripts/tests/` | **재작성** — 새 스키마 픽스처(valid/invalid/chapter) + run-tests.sh |
| — | `scripts/build-graph.py` | **신규** |
| — | `assets/graph.html` + `assets/lib/` | **신규** |
| 언어 규칙 (대화·본문 = 사용자 언어, 파일명·슬러그 영어 kebab-case, H2 리터럴 고정) | SKILL.md | **이식** |

이식하지 않는 것: modes.md(9모드), question-patterns.md, principles.md 의 인출
원칙들, cross-check.md(Context7 교차 확인), onboarding.md, host-compatibility.md,
gaps/confusions/cross-bridges/session-log 파일군, 구분자 아래 스킬 기록 규칙.

---

## 11. 세션 플로우

모드 라우터 없이 상태 기반 단순 분기. 매 호출 시:

1. **CWD 자체가 vault 루트인 경우를 글롭보다 먼저 본다** — `_global/config.md` 가
   CWD 에 바로 있으면 그 저장소를 후보로 삼는다. 아래 글롭은 CWD 의 하위
   디렉터리만 찾으므로 CWD 자신이 vault 루트일 때는 매치하지 않는다.
2. 위에서 못 찾았으면 `**/*-atlas/_global/config.md` 글롭으로 기존 저장소 탐색
   (`node_modules/`·`.git/` 제외).
   - 1개 → 사용자 확인 후 활성화. 여러 개 → 고르게 한다.
3. 저장소 없음 + CWD 에 PDF 있음 → **온보딩**. 사용자가 PDF 경로를 인자로 주면
   CWD 스캔 없이 그 파일을 온보딩 소스로 삼는다(경로가 존재하지 않으면 알리고
   다시 묻는다).
4. 저장소 없음 + PDF 없음 → 무엇을 정리할지 묻는다.

### 온보딩

1. 스캔본 검사 (샘플 3쪽 `pdftotext -layout`) — 스캔본이면 **중단**하고 사유 안내
   (이 스킬엔 개념 모드 폴백이 없다).
2. 목차 추출 → 계층 판정(상대 판정 5규칙) → 실패 시 복구 절차(toc-pipeline.md).
3. 오프셋 도출 → `verify-offset.sh` 3표본 검산 → 실패 시 멈추고 사용자에게 묻는다.
4. `source-manifest.md` 작성 → **트리·오프셋을 사용자에게 보여주고 확인**.
5. 언어·vault_name 질문 → `config.md` 작성.
6. 디렉터리 생성(전 챕터) · `_glossary.md` 빈 스캐폴드 · `graph/` 설치(뷰어+lib
   복사) · 첫 `build-graph.py` 실행 — 목차 뼈대 그래프가 이 시점부터 열린다.
7. PostToolUse 훅 설치 여부 질문 (선택).

### 정리 세션 (기본 루프)

1. `config.md` 진행 위치 확인 → 이번 단위(챕터 또는 이어서 할 절) 확정.
2. 새 챕터면: `_coverage.md` 왼쪽 세 열 채우기 → **분할·병합 규칙 적용**(§7) →
   `_chapter.md` 뼈대 생성.
3. 절 노트 작성 — `note-rules.md`·`figures.md` 를 먼저 읽는다. 원문은
   `pdftotext -layout -f <시작> -l <끝>` (오프셋은 manifest 참조, 매번 계산 금지).
4. 용어집 등재 → `check-note.sh` 실행, exit 2 면 고치고 재실행 → coverage 행
   상태 갱신.
5. 챕터 완결 시: `_chapter.md` 완성 → `check-chapter.sh` exit 0 확인 →
   `config.md` 진행 표를 `완료` 로.
6. **세션 종료 리추얼**: `build-graph.py` 실행 → 경고 리포트 확인·처리 →
   "graph.html 을 새로고침하세요" 안내. 진행 표 갱신.

### 가벼운 확인 (요청 시)

최근 정리한 절의 `## 스스로 확인` 질문을 던지고 가볍게 피드백한다.
막힘을 추적·기록하지 않는다. 사용자가 본격 인출 훈련을 원하면 deep-tutor 를
안내한다.

### 그래프 갱신/열기 (요청 시)

`build-graph.py` 재실행 + 열기 안내(`open graph/graph.html`).

---

## 12. 하드 룰 (SKILL.md 에 명시할 NEVER 목록)

1. `pdftotext` 를 `-layout` 없이 부르지 않는다.
2. 오프셋 검산에 실패하면 다른 오프셋을 추측해 재시도하지 않는다 — 멈추고 묻는다.
3. `source-manifest.md` 의 사용자 수정(`사용자수정` 상태)을 재파싱으로 덮어쓰지 않는다.
4. 구분자 아래 `## 내 메모` 를 덮어쓰거나 지우지 않는다 — 스킬은 그 아래에 아무것도 쓰지 않는다.
5. 노트는 `check-note.sh` 통과 전엔 완료(`status: done`)가 아니고, 챕터는 `check-chapter.sh` 통과 전엔 완료가 아니다.
6. 책 원문을 길게 옮기지 않는다 — 재구성해서 쓴다.
7. 용어집에 같은 용어를 두 번 정의하지 않는다.
8. `graph-data.js` 를 손으로 편집하지 않는다 — 항상 `build-graph.py` 로 재생성한다.
9. 목차에 없는 계층을 지어내지 않는다.
10. 정리 세션을 `build-graph.py` 실행 없이 끝내지 않는다.

---

## 13. 검증 게이트 상세

세 스크립트 모두 종료코드 계약: `0` 통과 · `2` 검사 실패(사유를 stderr 에 구체적으로) · `1` 사용법·입력 오류.

### `check-note.sh <노트경로>`

1. frontmatter 7키 존재 (book·chapter·section·title·pages·concepts·status)
2. 필수 H2 6개 — 구분자 위 스킬 영역 안에서
3. 도표 ≥1 — 언어 태그가 `mermaid` 또는 `text` 인 코드펜스, 또는 `![[_assets/`
   임베드만 도표로 인정한다 (`java`·`python` 등 코드 리스팅 펜스는 세지 않는다)
4. `## 연결` 항목 ≥2, 각 항목에 `[[링크]]` + `—` 뒤 관계 서술
5. 용어 전수 대조 — 코드펜스 제거 후 본문의 `[[슬러그]]`(및 frontmatter
   `concepts`)가 `_glossary.md` 의 `##` 첫 토큰에 전부 존재. `[[_` 접두 링크는
   건너뛴다(단 `[[_glossary#…]]` 앵커는 개념으로 대조).
6. 코드펜스 짝수 — 홀수면 하드 실패 (용어 대조 신뢰 불가)
7. 구분자 문자열 존재

### `check-chapter.sh <챕터경로>`

1. `_chapter.md`·`_coverage.md` 존재
2. coverage 가 참조하는 노트 파일 전부 존재
3. 챕터의 모든 노트가 `check-note.sh` 통과
4. coverage 에 사유 없는 `미반영`·`부분` 이 남아 있지 않다 (표는 마지막 열 헤더
   `상태` 로 찾는다)
5. 고아 노트 없음 — 챕터 안 노트는 전부 coverage 에 등장

### 훅 (선택)

`.claude/settings.json` PostToolUse — Write·Edit 대상이 `*-atlas/` 아래 노트
파일이면 `check-note.sh` 를 실행해 결과를 피드백. 기존 설정 파일이 있으면
**병합**한다(덮어쓰지 않는다).

### 테스트

`scripts/tests/run-tests.sh` — 픽스처: `valid/`(통과 노트+용어집),
`invalid/`(H2 누락·용어 미등재·연결 1개·코드펜스 홀수 등 실패 케이스별),
`chapter/`(coverage 완비 챕터). build-graph.py 도 같은 픽스처로 스모크 테스트
(산출 JS 가 파싱 가능하고 노드·엣지 수가 기대값과 일치).

---

## 14. 스킬 패키지 구조

```
~/Documents/claude-skill-set/book-atlas/
├── README.md · LICENSE(MIT) · install.sh · uninstall.sh    # tutor-skills 관례
├── docs/specs/2026-08-31-book-atlas-design.md              # 이 문서
└── skills/book-atlas/
    ├── SKILL.md                # frontmatter(name·description·allowed-tools) · 라우팅 · 하드 룰 · 세션 플로우 · 언어 규칙 · 셀프 리뷰 체크리스트
    ├── references/
    │   ├── toc-pipeline.md     # §10 참조
    │   ├── note-rules.md
    │   ├── figures.md
    │   ├── templates.md
    │   └── graph.md            # §9 데이터 계약·빌드·뷰어 사용법·문제해결
    ├── scripts/
    │   ├── verify-offset.sh · extract-figure.sh
    │   ├── check-note.sh · check-chapter.sh · check-note-hook.sh
    │   ├── build-graph.py
    │   └── tests/ (fixtures + run-tests.sh)
    └── assets/
        ├── graph.html
        └── lib/
            ├── 3d-force-graph.min.js
            └── VERSION.txt
```

- `install.sh` → `~/.claude/skills/book-atlas/` 복사, `uninstall.sh` 는 제거.
- SKILL.md description 트리거 예: "원서 정리", "교재 정리", "책 정리해줘",
  "PDF 책으로 공부", "개념 그래프", "book atlas". deep-tutor 와의 구분을
  description 에 명시한다(인출 훈련 요청은 deep-tutor 로).
- `<book-atlas-root>` 해석: 설치 후 `~/.claude/skills/book-atlas/`, 저장소 안에서
  실행 시 `skills/book-atlas/`. SKILL.md 에 한 줄로 명시(호스트 분기 없음).

## 15. 구현 순서 힌트 (계획 단계 입력)

1. 저장소 뼈대 + 이식 스크립트 2종 + 라이브러리 vendoring (네트워크 1회 필요)
2. templates.md · check-note.sh · check-chapter.sh + 테스트 픽스처
3. build-graph.py + 스모크 테스트
4. graph.html 뷰어
5. references 4종 (toc-pipeline · note-rules · figures · graph)
6. SKILL.md · README · install/uninstall
7. 실전 검증: 실제 PDF 1권으로 온보딩→1개 챕터 정리→그래프 확인

---

## 변경 이력

- 2026-09-01: 구현 확정 사항 반영 (§8·§9·§11·§14) — 최종 리뷰 권고.
- 2026-09-06: §7 분할 조건의 원문 분량 상수 조건을 제거하고 점검 신호로 강등 (SKILL-004) — 근거 없는 상수였고 실측 볼트에서 단독으로 작동한 적이 없음.
