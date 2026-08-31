# book-atlas 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원서 PDF를 목차 구조 그대로 정리하고 책→챕터→절→개념 연결을 three.js 3D 그래프로 시각화하는 Claude Code 스킬 패키지를 만든다.

**Architecture:** 마크다운 지침(SKILL.md + references 5종)이 로직의 본체이고, bash 검증 스크립트(check-note/check-chapter)가 구조 게이트, python3 빌더(build-graph.py)가 노트→그래프 데이터 변환, 정적 HTML(graph.html + vendored 3d-force-graph)이 뷰어다. deep-tutor 의 검증된 파일을 이식 지도(스펙 §10)에 따라 이식·각색·재작성한다.

**Tech Stack:** bash(macOS 기본 3.2 호환) · python3 표준 라이브러리만 · 3d-force-graph UMD 번들(three.js 포함, vendored) · pdftotext(poppler)

**Spec:** `docs/specs/2026-08-31-book-atlas-design.md` — 이 계획의 모든 "스펙 §N" 참조가 가리키는 문서. 실행자는 두 문서를 함께 읽는다.

## Global Constraints

- 저장소 루트: `/Users/singyupark/Documents/claude-skill-set/book-atlas/` (이미 git init 됨). 모든 경로는 이 루트 기준.
- 이식 원본: `/Users/singyupark/Documents/claude-skill-set/tutor-skills/개선판_스킬/deep-tutor/` — 이하 "DT 원본".
- bash 스크립트는 macOS 기본 bash 3.2 에서 돌아야 한다: `mapfile`·연관배열·`${var,,}` 금지 (DT 원본 스크립트가 이미 이 제약을 지킨다 — 같은 스타일 유지).
- python 은 `python3` 표준 라이브러리만. pip 의존 금지.
- 스크립트 종료코드 계약: `0` 통과 · `2` 검사 실패(사유를 stderr) · `1` 사용법·입력 오류.
- 필수 H2 리터럴 (로컬라이즈 금지): `## 한눈에 보기` `## 왜 이 절인가` `## 본문 정리` `## 개념` `## 연결` `## 스스로 확인`
- 구분자 리터럴: `<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->`
- frontmatter 7키: `book` `chapter` `section` `title` `pages` `concepts` `status`
- **위키링크 해석 규칙 (check-note.sh 와 build-graph.py 가 동일하게 적용):** `[[x]]` 는 vault 안에 `x.md` 파일이 존재하면 **노트 링크**, 없으면 **개념**(용어집 `## x` 대조 대상). `[[_` 접두 링크는 내부 파일 링크로 건너뛰되 `[[_glossary#s]]` 는 개념 `s` 로 해석. 코드펜스 안쪽은 항상 먼저 제거하고 추출한다.
- 도표 인정 기준: 언어 태그 `mermaid` 또는 `text` 인 코드펜스, 또는 `![[_assets/` 임베드만 (스펙 §13).
- 파일명·슬러그는 영어 kebab-case. 문서 본문은 한국어.
- 커밋: 태스크마다 1커밋. 메시지 형식 `feat(book-atlas): …` / `test(book-atlas): …`, 하네스가 요구하는 Co-Authored-By·Claude-Session 트레일러를 붙인다.
- 네트워크는 Task 1 의 라이브러리 vendoring 1회만 사용한다.

---

### Task 1: 저장소 뼈대 · 이식 스크립트 2종 · 라이브러리 vendoring

**Files:**
- Create: `.gitignore`, `LICENSE`
- Create: `skills/book-atlas/scripts/verify-offset.sh` (DT 원본 복사)
- Create: `skills/book-atlas/scripts/extract-figure.sh` (DT 원본 복사)
- Create: `skills/book-atlas/assets/lib/3d-force-graph.min.js`, `skills/book-atlas/assets/lib/VERSION.txt`

**Interfaces:**
- Produces: `verify-offset.sh <pdf> <book-page> <offset>` (exit 0/2/1), `extract-figure.sh <pdf> <page> <label> <out-dir>` — 이후 태스크·문서가 이 시그니처를 그대로 참조한다. `assets/lib/3d-force-graph.min.js` 는 전역 `ForceGraph3D` 를 정의하는 자체완결 UMD 번들.

- [ ] **Step 1: 디렉터리·기본 파일 생성**

```bash
cd /Users/singyupark/Documents/claude-skill-set/book-atlas
mkdir -p skills/book-atlas/{references,scripts/tests/fixtures,assets/lib}
printf '.DS_Store\n' > .gitignore
```

`LICENSE`: MIT 전문, 저작권자 `2026 singyupark`. (tutor-skills 저장소의 `개선판_스킬/LICENSE` 를 읽어 같은 형식으로 연도·이름만 맞춘다.)

- [ ] **Step 2: 스크립트 2종 이식 (수정 없이 복사)**

```bash
DT=/Users/singyupark/Documents/claude-skill-set/tutor-skills/개선판_스킬/deep-tutor
cp "$DT/scripts/verify-offset.sh" "$DT/scripts/extract-figure.sh" skills/book-atlas/scripts/
chmod +x skills/book-atlas/scripts/*.sh
```

- [ ] **Step 3: 이식 검증 — 인자 없이 실행하면 usage 로 exit 1**

Run: `skills/book-atlas/scripts/verify-offset.sh; echo "exit=$?"` → 기대: usage 메시지 + `exit=1`
Run: `skills/book-atlas/scripts/extract-figure.sh; echo "exit=$?"` → 기대: usage 메시지 + `exit=1`

- [ ] **Step 4: 3d-force-graph vendoring (네트워크 1회)**

```bash
curl -fsSL -o skills/book-atlas/assets/lib/3d-force-graph.min.js \
  "https://unpkg.com/3d-force-graph@1/dist/3d-force-graph.min.js"
curl -fsSL "https://unpkg.com/3d-force-graph@1/package.json" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])" \
  > skills/book-atlas/assets/lib/VERSION.txt
```

- [ ] **Step 5: 번들 검증**

Run: `grep -c "ForceGraph3D" skills/book-atlas/assets/lib/3d-force-graph.min.js` → 기대: 1 이상
Run: `wc -c < skills/book-atlas/assets/lib/3d-force-graph.min.js` → 기대: 500000 초과 (three.js 포함 자체완결 번들의 크기 서명. 수십 KB 수준이면 three 미포함 빌드를 받은 것 — 그 경우 `https://unpkg.com/3d-force-graph@1/dist/3d-force-graph.js` 등 dist 목록을 확인해 three 를 내장한 번들로 교체한다)
Run: `cat skills/book-atlas/assets/lib/VERSION.txt` → 기대: `1.x.y` 형식

- [ ] **Step 6: Commit** — `feat(book-atlas): 뼈대 + 이식 스크립트 + 3d-force-graph vendoring`

---

### Task 2: templates.md + 테스트 픽스처 전체

**Files:**
- Create: `skills/book-atlas/references/templates.md`
- Create: `skills/book-atlas/scripts/tests/fixtures/vault/` (아래 트리 전체)
- Create: `skills/book-atlas/scripts/tests/fixtures/invalid/` (실패 노트 6종 + `_glossary.md`)
- Create: `skills/book-atlas/scripts/tests/fixtures/chapter-bad/` (check-chapter 실패 케이스)

**Interfaces:**
- Produces: 픽스처 경로들 — Task 3~5 의 테스트가 이 경로를 하드코딩으로 참조한다. `vault/` 는 통과 케이스이자 build-graph 의 기대값 원천(노드 8 · 링크 10 · 경고 1). templates.md 의 노트 예시와 `vault/chapter-01-intro/01-what-is-retrieval.md` 는 **같은 내용**이다(문서의 예시가 곧 통과 픽스처).

- [ ] **Step 1: 픽스처 vault 트리 생성**

```
fixtures/vault/
├── _global/config.md
├── _global/source-manifest.md
├── _glossary.md
└── chapter-01-intro/
    ├── _chapter.md
    ├── _coverage.md
    ├── 01-what-is-retrieval.md
    └── 02-ranking.md
```

`_global/config.md`:

```markdown
# Config

## 기본
- book_slug: sample-book
- book_title: Sample Book
- language: ko
- vault_name: TestVault
- source_pdf: ../sample.pdf

## 진행 위치
| 챕터 | 상태 | 다음 |
|---|---|---|
| chapter-01-intro | 진행 중 | 02-ranking |
```

`_global/source-manifest.md`:

```markdown
# Source Manifest

## 소스
- book_slug: sample-book
- book_title: Sample Book
- pdf: ../sample.pdf

## 쪽 오프셋
| 구간 | 오프셋 | 검산 |
|---|---|---|
| Ch.1–2 | 8 | 왕복 3/3 일치 |

## 목차 트리
| 계층 | 번호 | 제목 | 슬러그 | 시작 책쪽 | 상태 |
|---|---|---|---|---:|---|
| chapter | 1 | Intro | chapter-01-intro | 1 | 파싱됨 |
| section | 1 | What Is Retrieval | 01-what-is-retrieval | 2 | 파싱됨 |
| section | 2 | Ranking | 02-ranking | 5 | 파싱됨 |
| chapter | 2 | More | chapter-02-more | 9 | 파싱됨 |
| section | 1 | Advanced | 01-advanced | 10 | 파싱됨 |
```

`_glossary.md` (embedding 항목은 어느 노트도 참조하지 않는다 — build-graph 경고 테스트용):

```markdown
# 용어집

## retrieval (retrieval)
질문과 관련된 문서를 먼저 찾아오는 단계다. 쉽게 말해 도서관 사서가 책부터 뽑아 오는 일이다.
- 처음 나온 곳: [[01-what-is-retrieval]]
- 섞이는 말: [[context]] — retrieval 은 찾는 행위, context 는 찾아온 결과물

## context (context)
모델에 함께 넣어 주는 참고 자료다.
- 처음 나온 곳: [[01-what-is-retrieval]]

## embedding (embedding)
텍스트를 숫자 벡터로 바꾼 표현이다.
```

`chapter-01-intro/01-what-is-retrieval.md` (**모든 게이트 통과 — templates.md 예시와 동일 내용**):

```markdown
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

- [[02-ranking]] — 여기서 찾아온 문서를 다음 절이 순위 매긴다
- [[context]] — retrieval 의 산출물이 context 로 들어간다

## 스스로 확인

- retrieval 없이 모델만으로 답할 때 무엇이 먼저 깨지나?
- context 가 커질수록 무엇이 나빠지나?

<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->

## 내 메모
```

`chapter-01-intro/02-ranking.md` — 같은 골격으로 작성하되: frontmatter `section: "1.2"` · `title: "Ranking"` · `pages: "책 p.5–8 / PDF p.13–16"` · `concepts: [context]` · `status: draft`. 본문 어딘가에 `[[retrieval]]` 언급 1회, 도표는 `text` 펜스 1개, `## 연결` 은 `- [[01-what-is-retrieval]] — 앞 절이 찾아온 문서를 이 절이 순위 매긴다` 와 `- [[retrieval]] — 순위의 입력이 retrieval 결과다` 2개. 나머지 필수 H2·구분자 모두 포함.

`chapter-01-intro/_coverage.md`:

```markdown
# Chapter 01 원문 커버리지

## 1. 원문 절 → 노트 매핑
| 책 쪽 | PDF 쪽 | 원문 절 | 정리 노트 | 상태 |
|---|---|---|---|---|
| 2–4 | 10–12 | What Is Retrieval | [[01-what-is-retrieval]] | 반영 |
| 5–8 | 13–16 | Ranking | [[02-ranking]] | 반영 |

## 2. 코드·예제 커버리지
| 원문 예제 | 노트 | 설명 보강 |
|---|---|---|
```

`chapter-01-intro/_chapter.md` — 5요소(논지 한 문단 · 읽는 순서 mermaid · 노트→질문 표 · `[[_coverage]]` 링크 문장 · 구분자+`## 내 메모`)를 모두 갖춘 짧은 예시로 작성.

- [ ] **Step 2: invalid 픽스처 6종 생성**

`fixtures/invalid/_glossary.md`: vault 것에서 embedding 항목만 뺀 사본.
각 실패 노트는 `01-what-is-retrieval.md` 를 복사한 뒤 **먼저 `## 연결` 의
`[[02-ranking]]` 을 `[[retrieval]]` 로 바꾼다** (이 디렉터리엔 `02-ranking.md` 가
없어 미등재 개념으로 오판되면 실패 사유가 오염된다 — 각 픽스처는 의도한 한 가지
사유로만 실패해야 한다). 그다음 **한 가지만** 깨뜨린다:

| 파일 | 깨뜨리는 것 | 기대 stderr 키워드 |
|---|---|---|
| `missing-h2.md` | `## 연결` 섹션 통째 삭제 | `섹션 누락` |
| `missing-term.md` | 본문에 `[[undefined-term]]` 한 줄 추가 | `용어집에 없` |
| `one-link.md` | `## 연결` 항목을 1개만 남김 | `연결` |
| `odd-fence.md` | mermaid 닫는 ``` 한 줄 삭제 | `코드펜스` |
| `no-diagram.md` | mermaid 펜스의 언어 태그를 `java` 로 변경 | `도표` |
| `no-separator.md` | 구분자 줄 삭제 | `구분자` |

- [ ] **Step 3: chapter-bad 픽스처 생성**

```
fixtures/chapter-bad/
├── _glossary.md            # invalid/ 것과 동일 사본 (03-orphan.md 의 걸어올라가기용)
├── _chapter.md             # vault 것 복사
├── _coverage.md            # 표 1 행: [[01-exists-not]] 반영  ← 파일 없음
└── 03-orphan.md            # 01-what-is-retrieval.md 사본에서 frontmatter section/title 만 바꾼 통과 노트
                            #   단 ## 연결의 [[02-ranking]] 은 [[retrieval]] 로 교체 (이 디렉터리엔 02 가 없으므로)
```

기대 실패 2건: coverage 가 참조하는 `01-exists-not.md` 부재 + `03-orphan.md` 가 coverage 에 없음(고아).

- [ ] **Step 4: templates.md 작성**

DT 원본 `references/templates.md` 의 **형식**(각 파일마다 "무엇을 쓰는가" 표 + 전체 예시 코드블록)을 따르되 내용은 새 스키마로 재작성. 반드시 포함: ① `_global/config.md` (스펙 §2 필드) ② `_global/source-manifest.md` (목차 트리 표·오프셋 구간 표·상태값 3종 의미) ③ 절 노트 (frontmatter 7키 각각의 의미 표 + 필수 H2 6개 표 + 위 Step 1 의 `01-what-is-retrieval.md` 전문을 예시로) ④ `_chapter.md` (5요소) ⑤ `_coverage.md` (표 2개, 상태값, 병합 행 규칙) ⑥ `_glossary.md` (항목 형식·중복 금지·섞이는 말) ⑦ 구분자 원칙 ⑧ 훅 설정 JSON 조각(Task 8 의 check-note-hook.sh 를 가리키는 `.claude/settings.json` PostToolUse 예시). 각 항목 끝에 "스킬 소유 / 사용자 소유 / 정본" 소유권 한 줄.

- [ ] **Step 5: 육안 검증** — templates.md 의 노트 예시와 픽스처 파일이 문자 단위로 같은지 `diff <(예시 추출) 픽스처` 대신, 예시를 픽스처에서 복사해 넣는 순서로 작성했음을 확인. `find skills/book-atlas/scripts/tests/fixtures -type f | wc -l` → 기대: 18 (vault 7 · invalid 7 · chapter-bad 4)
- [ ] **Step 6: Commit** — `feat(book-atlas): templates.md + 테스트 픽스처(vault·invalid·chapter-bad)`

---

### Task 3: check-note.sh + run-tests.sh

**Files:**
- Create: `skills/book-atlas/scripts/check-note.sh`
- Create: `skills/book-atlas/scripts/tests/run-tests.sh`
- Reference: DT 원본 `scripts/check-note.sh` (구조·bash 관용구 참고용 — 검사 목록은 다름)

**Interfaces:**
- Consumes: Task 2 픽스처 경로들.
- Produces: `check-note.sh <노트경로>` → exit 0/2/1. 용어집 탐색 규칙: **노트가 있는 디렉터리에서 위로 최대 4단계 걸어 올라가며 `_glossary.md` 를 가진 첫 디렉터리** 사용, 그 디렉터리가 vault 루트 판정 기준도 겸한다(노트 링크 존재 검사 `find <그 디렉터리> -name "x.md"`). 못 찾으면 exit 1. `run-tests.sh` 는 케이스 추가형 하니스 — Task 4·5 가 케이스를 덧붙인다.

- [ ] **Step 1: run-tests.sh 하니스 + check-note 케이스 작성 (실패하는 테스트)**

```bash
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
```

- [ ] **Step 2: 실패 확인**

Run: `skills/book-atlas/scripts/tests/run-tests.sh` → 기대: 전 케이스 FAIL (check-note.sh 부재로 exit 126/127)

- [ ] **Step 3: check-note.sh 구현**

DT 원본의 골격(ok/bad 헬퍼, stderr 사유 출력, 최종 exit 판정)을 따르되 검사 내용은 스펙 §13 그대로. 구현 순서와 핵심 기법:

1. **인자·용어집 탐색**: 인자 1개 필수(없으면 usage, exit 1). 노트 디렉터리에서 `for i in 1 2 3 4` 로 `../` 반복하며 `_glossary.md` 탐색 → 찾은 디렉터리를 `VROOT` 로. 못 찾으면 exit 1.
2. **구분자 분리**: `above=$(sed "/<!-- ==== 아래는 내 메모/q" "$note")` — 구분자 위 영역만 이후 검사 대상. 구분자 자체가 없으면 bad "구분자 없음".
3. **frontmatter 7키**: 첫 줄이 `---` 인지, 둘째 `---` 까지 블록에서 `^book:` `^chapter:` `^section:` `^title:` `^pages:` `^concepts:` `^status:` 각각 존재.
4. **필수 H2 6개**: `above` 에서 `grep -qF "## 한눈에 보기"` 등 6개 (Global Constraints 리터럴).
5. **코드펜스 짝수**: `n=$(printf '%s\n' "$above" | grep -c '^```')` 홀수면 bad(하드 실패 — 이후 용어 검사 신뢰 불가 사유 명시).
6. **도표**: `above` 에서 `grep -qE '^```(mermaid|text)$'` 또는 `grep -qF '![[_assets/'` — 어느 쪽도 없으면 bad "도표".
7. **연결 ≥2**: `## 연결` 부터 다음 `^## ` 전까지 잘라 `grep -cE '^- \[\[.+\]\] — .+'` ≥ 2.
8. **펜스 제거**: `stripped=$(printf '%s\n' "$above" | awk '/^```/{f=!f;next} !f')` — 이후 용어 추출은 stripped 에서만.
9. **용어 전수 대조**: stripped 에서 `grep -oE '\[\[[^]]+\]\]'` → 각 항목에서 `[[ ]]` 벗기고 `|` 별칭·`#` 앵커 처리: `_glossary#s` → 개념 `s`, 그 외 `_` 접두 → 건너뜀. frontmatter `concepts: [a, b]` 도 파싱해 후보에 합침. 각 후보 `t` 에 대해: `find "$VROOT" -name "$t.md" -not -path '*/graph/*'` 가 비어 있지 않으면 노트 링크(통과), 비어 있으면 `grep -qE "^## $t( |$)" "$VROOT/_glossary.md"` — 실패 시 bad "용어집에 없음: $t".
10. 실패가 하나라도 있으면 exit 2, stderr 에 항목별 사유. 전부 통과면 exit 0.

- [ ] **Step 4: 통과 확인**

Run: `skills/book-atlas/scripts/tests/run-tests.sh` → 기대: `pass=9 fail=0`, exit 0

- [ ] **Step 5: Commit** — `feat(book-atlas): check-note.sh + 테스트 하니스 (9케이스)`

---

### Task 4: check-chapter.sh

**Files:**
- Create: `skills/book-atlas/scripts/check-chapter.sh`
- Modify: `skills/book-atlas/scripts/tests/run-tests.sh` (케이스 3개 추가)

**Interfaces:**
- Consumes: `check-note.sh` (같은 디렉터리에서 `"$(dirname "$0")/check-note.sh"` 로 호출), Task 2 픽스처.
- Produces: `check-chapter.sh <챕터경로>` → exit 0/2/1.

- [ ] **Step 1: 케이스 추가 (실패하는 테스트)** — run-tests.sh 의 check-note 블록 아래에:

```bash
expect 0 "check-chapter: 통과 챕터"     -- "$S/check-chapter.sh" "$F/vault/chapter-01-intro"
expect 2 "check-chapter: 누락 참조+고아" -- "$S/check-chapter.sh" "$F/chapter-bad"
expect 1 "check-chapter: 인자 없음"     -- "$S/check-chapter.sh"
```

- [ ] **Step 2: 실패 확인** — Run: `run-tests.sh` → 기대: 새 3케이스 FAIL, 기존 9 PASS

- [ ] **Step 3: check-chapter.sh 구현** — 검사 5종 (스펙 §13):

1. 인자 = 디렉터리(아니면 exit 1). `_chapter.md`·`_coverage.md` 존재.
2. coverage 에서 **마지막 열 헤더가 `상태` 인 표**를 찾는다: `| ... | 상태 |` 헤더 행 이후 `|` 로 시작하는 행들. 각 행의 정리 노트 칸에서 `\[\[([^]]+)\]\]` 추출 → `<챕터경로>/{이름}.md` 존재 확인. 없으면 bad "coverage 참조 노트 없음: {이름}".
3. 상태 칸이 정확히 `미반영` 또는 `부분` **뿐**(뒤에 사유 텍스트 없음)이면 bad "사유 없는 {값}".
4. 챕터 안 `[0-9][0-9]*-*.md` 글롭 각각이 coverage 본문에 `[[basename]]` 로 등장하는지 — 없으면 bad "고아 노트: {파일}".
5. 위 글롭의 모든 노트에 `check-note.sh` 실행 — 하나라도 exit 2 면 bad "노트 게이트 실패: {파일}".

- [ ] **Step 4: 통과 확인** — Run: `run-tests.sh` → 기대: `pass=12 fail=0`
- [ ] **Step 5: Commit** — `feat(book-atlas): check-chapter.sh (+3케이스)`

---

### Task 5: build-graph.py

**Files:**
- Create: `skills/book-atlas/scripts/build-graph.py`
- Modify: `skills/book-atlas/scripts/tests/run-tests.sh` (스모크 어서션 블록 추가)

**Interfaces:**
- Consumes: 픽스처 vault, Global Constraints 의 위키링크 해석 규칙.
- Produces: `python3 build-graph.py <vault-root>` → `<vault-root>/graph/graph-data.js` 생성(디렉터리 없으면 mkdir), stderr 에 `경고: ` 접두 리포트, exit 0(경고 있어도) / 1(`_global/config.md` 없음). 데이터 계약은 스펙 §9.1 — 노드 id 형식 `book:{slug}` `chapter:{dirname}` `note:{vault상대경로, .md 제외}` `concept:{slug}`, 링크 type 5종(`toc` `covers` `mentions` `related` `note-link`). Task 6 뷰어가 이 계약을 그대로 소비한다.

- [ ] **Step 1: 스모크 테스트 추가 (실패하는 테스트)** — run-tests.sh 끝(요약 줄 위)에:

```bash
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
```

- [ ] **Step 2: 실패 확인** — Run: `run-tests.sh` → 기대: build-graph 3케이스 FAIL, 기존 12 PASS

- [ ] **Step 3: build-graph.py 구현** — 단일 파일, 함수 구성과 규칙:

```python
#!/usr/bin/env python3
"""book-atlas 그래프 빌더 — vault 를 스캔해 graph/graph-data.js 를 재생성한다."""
import sys, re, json, datetime
from pathlib import Path
```

- `parse_kv(path)` — `- key: value` 줄들을 dict 로 (config·manifest 소스 절 공용).
- `parse_manifest(path)` — 목차 트리 표를 행 단위 파싱: `| 계층 | 번호 | 제목 | 슬러그 | ...`. `chapter` 행마다 `{dir=슬러그, label=f"{번호}. {제목}", lowest=0}`, 이어지는 `section`/`subsection` 행은 직전 chapter 의 `lowest` 에 +1 (subsection 이 있는 챕터는 subsection 만 세고 section 은 부모 취급 — **subsection 행이 하나라도 있으면 그 챕터의 section 행은 세지 않는다**).
- `strip_fences(text)` / `wiki_links(text)` — awk 와 동일 의미의 정규식: 펜스 토글 후 `\[\[([^\]]+)\]\]`, `|` 별칭 앞부분만, `_glossary#s`→`s`, 그 외 `_` 접두 제외.
- `parse_frontmatter(text)` — 첫 `---` 쌍 안에서 `key: value` (concepts 는 `\[(.*)\]` 인라인 리스트).
- `parse_glossary(path)` — `^## (\S+)(?: \((.+)\))?` 항목들: slug, def(제목 다음 첫 비어있지 않은 줄, 120자 절단), related(`- 섞이는 말: [[s]]` 의 s).
- 수집: vault 상대 글롭 `**/chapter-*/[0-9]*.md` 로 노트, 노트별 frontmatter·본문(구분자 위) 링크·`## 연결` 섹션 링크.
- 엣지 생성: `toc`(book→각 manifest chapter, chapter→그 디렉터리의 각 노트) · `covers`(frontmatter concepts) · `mentions`(본문+연결의 개념 링크, **covers 와 같은 쌍이면 생략**) · `note-link`(`## 연결` 의 노트 링크만, 무방향 — `tuple(sorted(...))` 로 중복 제거) · `related`(용어집 섞이는 말, 무방향 중복 제거). 모든 (source,target,type) 중복 제거.
- `progress`: 챕터에 노트 파일이 있으면 `{done: status==done 수, total: 노트 파일 수}`, 없으면 `{done: 0, total: manifest lowest}`.
- 경고(stderr, `경고: ` 접두): ① 용어집에 없는 개념 참조 ② 존재하지 않는 노트로 가는 링크 ③ `_coverage.md` 에 없는 노트 ④ 어느 노트·frontmatter 도 참조하지 않는 용어집 항목.
- 출력: `graph/` mkdir 후 `window.ATLAS_DATA = {json.dumps(data, ensure_ascii=False, indent=2)};` — `generated` 는 `datetime.datetime.now().isoformat(timespec="seconds")`.
- `_global/config.md` 없으면 stderr 사유 + exit 1.

- [ ] **Step 4: 통과 확인** — Run: `run-tests.sh` → 기대: `pass=15 fail=0`
- [ ] **Step 5: Commit** — `feat(book-atlas): build-graph.py (+데이터 계약 스모크 3케이스)`

---

### Task 6: graph.html 뷰어

**Files:**
- Create: `skills/book-atlas/assets/graph.html`

**Interfaces:**
- Consumes: `./graph-data.js` 의 `window.ATLAS_DATA` (스펙 §9.1), `./lib/3d-force-graph.min.js` 의 전역 `ForceGraph3D`.
- Produces: 없음 (말단). vault 배치 기준 상대 경로 — `graph/graph.html` 옆에 `graph-data.js`, `lib/`.

- [ ] **Step 1: 구현** — 단일 HTML, 외부 참조는 위 두 상대경로뿐. 구조와 핵심 로직:

```html
<!doctype html><html lang="ko"><head><meta charset="utf-8">
<title>book-atlas graph</title>
<style>
  html,body{margin:0;height:100%;background:#0e1117;color:#c9d1d9;font:13px/1.5 -apple-system,sans-serif}
  #panel{position:fixed;top:12px;left:12px;background:#161b22cc;border:1px solid #30363d;
         border-radius:8px;padding:12px;width:230px;z-index:2}
  #info{position:fixed;top:12px;right:12px;background:#161b22cc;border:1px solid #30363d;
        border-radius:8px;padding:12px;width:260px;z-index:2;display:none}
  label{display:block;margin:2px 0} input[type=text]{width:100%;box-sizing:border-box;
        background:#0d1117;color:inherit;border:1px solid #30363d;border-radius:4px;padding:4px}
  .sw{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:6px}
</style></head><body>
<div id="panel">
  <input type="text" id="search" placeholder="노드 검색…">
  <div style="margin-top:8px"><b>레이어</b>
    <label><input type="checkbox" id="layer-toc" checked> 목차 (책·챕터·절)</label>
    <label><input type="checkbox" id="layer-concepts" checked> 개념</label></div>
  <div style="margin-top:8px"><b>엣지</b>
    <label><input type="checkbox" id="edge-toc" checked> 목차 계층</label>
    <label><input type="checkbox" id="edge-covers" checked> 핵심 개념</label>
    <label><input type="checkbox" id="edge-mentions" checked> 언급</label>
    <label><input type="checkbox" id="edge-related" checked> 개념 관계</label>
    <label><input type="checkbox" id="edge-note-link" checked> 노트 연결</label></div>
  <div style="margin-top:8px" id="legend"></div>
</div>
<div id="info"></div><div id="graph"></div>
<script src="./lib/3d-force-graph.min.js"></script>
<script src="./graph-data.js"></script>
<script> /* 아래 로직 */ </script></body></html>
```

스크립트 로직 (함수 이름 고정):

- `COLORS = {book:'#f6c945', chapter:'#ff8c42', note:'#4ecdc4', concept:'#b085f5'}`; `LAYER = {book:'toc', chapter:'toc', note:'toc', concept:'concepts'}` — 범례는 COLORS 로 생성.
- 시작 시 전체 데이터에서 `degree` 맵 계산(양끝 +1) → `nodeVal = 2 + degree*1.5`.
- `applyFilters()` — 체크박스 상태로 노드(레이어)·링크(타입) 필터, 숨은 노드에 닿는 링크 제거 → `Graph.graphData(filtered)`. 모든 체크박스 `change` 에 연결.
- `Graph = ForceGraph3D()(el)` 설정: `.backgroundColor('#0e1117')` `.nodeLabel(n => n.label)` `.nodeVal(...)` `.nodeColor(n => hl.size && !hl.has(n.id) ? '#30363d' : (n.status==='draft' ? COLORS.note+'59' : COLORS[n.type]))` `.linkWidth(l => l.type==='covers'?2:1)` `.linkColor(l => ({toc:'#8b949e',covers:'#4ecdc4',mentions:'#4ecdc466',related:'#b085f5',['note-link']:'#4ecdc4aa'}[l.type]))`.
- 호버 하이라이트: `hl = new Set()`; `.onNodeHover(n => { hl.clear(); if(n){hl.add(n.id); links.forEach(l => {if(끝점이 n) {hl.add(양끝)}})} Graph.nodeColor(Graph.nodeColor()); })` — 인접 계산은 필터된 현재 링크 기준.
- 클릭: `.onNodeClick(n => { const v = ATLAS_DATA.book.vault; if(n.path && v){ location.href = 'obsidian://open?vault='+encodeURIComponent(v)+'&file='+encodeURIComponent(n.path.replace(/\.md$/,'')); } else if(n.type==='concept' && v){ location.href = 'obsidian://open?vault='+encodeURIComponent(v)+'&file='+encodeURIComponent('_glossary'); } else showInfo(n); })`.
- `showInfo(n)` — `#info` 에 label·type·(concept 이면 def, note 면 status·path) 표시.
- 검색: `input` 이벤트 — 소문자 부분일치 첫 노드에 `hl` 설정 + `Graph.cameraPosition({x,y,z: 거리}, node, 800)` (라이브러리 문서의 focus 예제 패턴: 노드 좌표×1.4 배율).

- [ ] **Step 2: 수동 검증 (브라우저)**

```bash
TMP="$(mktemp -d)"; cp -R skills/book-atlas/scripts/tests/fixtures/vault "$TMP/v"
python3 skills/book-atlas/scripts/build-graph.py "$TMP/v"
cp skills/book-atlas/assets/graph.html "$TMP/v/graph/"
cp -R skills/book-atlas/assets/lib "$TMP/v/graph/lib"
open "$TMP/v/graph/graph.html"
```

체크리스트(사람 눈): ① 노드 8개, 4색 + 범례 ② `02-ranking`(draft) 반투명 ③ 레이어 "개념" 해제 시 보라 노드 3개 소멸 ④ 호버 시 이웃만 밝음 ⑤ 검색 `retrieval` 입력 시 카메라 이동 ⑥ 클릭 시 obsidian:// 시도(설치 안 된 vault 명이면 무시됨 — 오류 아님) ⑦ 콘솔 에러 0.

- [ ] **Step 3: Commit** — `feat(book-atlas): graph.html 뷰어 (레이어 토글·호버 하이라이트·검색·Obsidian 클릭)`

---

### Task 7: references 4종 (toc-pipeline · note-rules · figures · graph)

**Files:**
- Create: `skills/book-atlas/references/toc-pipeline.md` — 원본: DT `references/book-mode.md`
- Create: `skills/book-atlas/references/note-rules.md` — 원본: DT `references/note-authoring.md`
- Create: `skills/book-atlas/references/figures.md` — 원본: DT `references/figures.md`
- Create: `skills/book-atlas/references/graph.md` — 신규 (스펙 §9 기반)

**Interfaces:**
- Consumes: 스펙 §9·§10, templates.md (섹션명 참조), 스크립트 시그니처(Task 1·3·4·5).
- Produces: SKILL.md(Task 8)가 참조하는 4개 문서 — 파일명·절 구성이 여기서 확정된다.

- [ ] **Step 1: toc-pipeline.md** — book-mode.md §2~§9 를 옮기되 **각 절에 이 변경만** 적용:
  - §2 모드 판정 → "판정" 절로: 개념 모드 폴백 문장 전부 삭제, 실패 시 행동은 "중단하고 사유 안내"(스캔본) 또는 복구 절차(그 외). `structure:` config 필드 언급 삭제(이 스킬엔 모드가 하나뿐).
  - §3~§7 (목차 추출·계층 판정 5규칙·오프셋 검산·실패 분류·부분 실패·정본 원칙): 실측 사례 포함 **그대로 유지**. 치환만: `<deep-tutor-root>` → `<book-atlas-root>`, `{domain}-notes` → `{book-slug}-atlas`, `_global/config.md 의 오프셋` 언급 → `source-manifest.md`.
  - §8 디렉터리 생성: 챕터 번호 0패딩(`chapter-NN-`) 반영, 챕터 안 생성 파일 목록을 `_chapter.md`·`_coverage.md` 로 교체(`_map.md`·`_glossary.md`·`_assets/` 챕터별 생성 삭제 — 용어집·assets 는 vault 루트, 스펙 §2). `graph/` 설치(뷰어+lib 복사, 첫 빌드) 단계 추가.
  - §9 분할·병합: 그대로 + 스펙 §7 에 추가된 "목차 자체 subsection 은 곧바로 NNa- 노트" 문단 반영. `check-note.sh 통과` 문구는 새 스크립트 기준으로.
  - §10(챕터 _map)·§11(공존)·§12(part-0) 은 **옮기지 않는다** — §10 자리는 "챕터 개요 `_chapter.md` 는 templates.md 를 본다" 한 줄로.
- [ ] **Step 2: note-rules.md** — note-authoring.md 를 옮기되: 규칙 12개·위반/교정 예시 쌍·완료 게이트 유지. 치환: `## 7. 연결`→`## 연결`, `## 3. 그림으로 보기`→"도표는 위치 자유·존재 검사", `## 4. 이 노트에 나온 용어`→`## 개념`, `1단계/2단계/3단계` 인출 서사 삭제(§7 "3단계에서 보강" 절 전체 삭제), 용어집 운영 절은 vault 루트 단일 `_glossary.md` 기준으로 수정, 저작권 절 유지. 완료 게이트 체크리스트의 (모델 판단)/(check-note.sh) 표기는 새 검사 목록에 맞게 갱신.
- [ ] **Step 3: figures.md** — 거의 그대로 복사. 치환: `## 3. 그림으로 보기` 언급 → "본문 정리의 해당 위치", `<deep-tutor-root>` → `<book-atlas-root>`, `_assets` 위치는 vault 루트, 오프셋 참조는 `source-manifest.md`, `check-note.sh` 의 도표 인정 기준(mermaid/text 펜스·embed)을 §4 끝에 한 문단 추가.
- [ ] **Step 4: graph.md 신규 작성** — 절 구성: ① 데이터 계약(스펙 §9.1 의 노드·링크 표를 그대로) ② `build-graph.py` 사용법·경고 4종의 의미와 대응 ③ 뷰어 기능표·조작법 ④ Obsidian 클릭이 안 될 때(vault_name 확인·URI 인코딩) ⑤ "graph-data.js 는 손 편집 금지 — 항상 재생성" 경고.
- [ ] **Step 5: 검증** — 4파일 각각에 대해: 깨진 상호 참조 없는지 `grep -n "deep-tutor\|_map.md\|-notes/\|## 7\." skills/book-atlas/references/*.md` → 기대: 0건 (이식 출처 언급으로 남긴 의도적 문구 제외 — 남긴 경우 사유를 눈으로 확인).
- [ ] **Step 6: Commit** — `feat(book-atlas): references 4종 (toc-pipeline·note-rules·figures·graph)`

---

### Task 8: SKILL.md + check-note-hook.sh

**Files:**
- Create: `skills/book-atlas/SKILL.md`
- Create: `skills/book-atlas/scripts/check-note-hook.sh` — 원본: DT `scripts/check-note-hook.sh`
- Modify: `skills/book-atlas/scripts/tests/run-tests.sh` (훅 케이스 2개)

**Interfaces:**
- Consumes: references 4종 + templates.md 파일명, 스크립트 시그니처 전부.
- Produces: `/book-atlas` 스킬 진입점. 훅은 stdin 으로 PostToolUse JSON 을 받아 `*-atlas/` 아래 `NN*.md` 노트면 check-note.sh 를 실행.

- [ ] **Step 1: 훅 테스트 추가 (실패하는 테스트)** — run-tests.sh 에:

```bash
note="$F/vault/chapter-01-intro/01-what-is-retrieval.md"
expect 0 "hook: atlas 노트에 게이트 실행" -- bash -c \
  'printf "{\"tool_input\":{\"file_path\":\"%s\"}}" "$1" | "$2"' _ "$note" "$S/check-note-hook.sh"
expect 0 "hook: 비대상 파일은 무시" -- bash -c \
  'printf "{\"tool_input\":{\"file_path\":\"/tmp/readme.md\"}}" | "$1"' _ "$S/check-note-hook.sh"
```

주의: 픽스처 경로에는 `-atlas` 가 없으므로 훅의 대상 판정은 "**가장 가까운 조상 중 `_glossary.md` 를 가진 디렉터리가 있고, 파일명이 `[0-9]` 로 시작하며 `_` 접두가 아닌 .md**" 로 정의한다(경로 이름 의존 제거 — DT 훅이 `-notes` 고정 오프셋에서 겪은 결함의 교훈). 실제 vault 에서도 픽스처에서도 같은 규칙으로 동작한다.

- [ ] **Step 2: 실패 확인** — Run: `run-tests.sh` → 훅 2케이스 FAIL
- [ ] **Step 3: check-note-hook.sh 각색** — DT 원본에서: stdin JSON 의 `file_path` 추출(원본의 python3 한 줄 파서 유지), 대상 판정을 Step 1 규칙으로 교체, 대상이면 `"$(dirname "$0")/check-note.sh" "$file"` 실행하고 결과를 원본과 같은 형식(통과 조용히/실패 시 stderr 사유 전달)으로 출력, 비대상이면 exit 0. Codex 분기 삭제.
- [ ] **Step 4: 통과 확인** — Run: `run-tests.sh` → 기대: `pass=17 fail=0`
- [ ] **Step 5: SKILL.md 작성** — frontmatter 는 이 내용 그대로:

```yaml
---
name: book-atlas
description: >
  원서 PDF 한 권을 목차 구조 그대로 충실하게 정리하고, 책→챕터→절→개념 연결을
  three.js 3D 그래프로 시각화하는 정리 중심 학습 스킬. 목차 추출·쪽 오프셋 검산으로
  저장소를 부트스트랩하고, 절 단위 노트(작성 규칙 12개)와 책 전체 용어집을 만들며,
  세션마다 그래프를 재생성한다. 사용자가 "원서 정리", "교재 정리", "책 정리해줘",
  "PDF 로 공부", "개념 그래프", "book atlas" 같은 요청을 하면 이 스킬을 쓴다.
  인출 훈련(퀴즈·꼬리질문·암기)은 이 스킬의 몫이 아니다 — 그 요청은 deep-tutor 로
  안내한다.
argument-hint: "[PDF 경로 | 정리 | 그래프 | 확인]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---
```

본문 절 구성 (내용 출처를 명시한다 — 실행자는 스펙 해당 절의 문장을 기반으로 쓴다):

1. **핵심 철학** 3문장: 정리가 본체, 그래프는 노트의 파생물, 인출은 deep-tutor 의 몫.
2. **`<book-atlas-root>` 해석** 한 줄: 설치 후 `~/.claude/skills/book-atlas/`, 저장소 안 실행 시 `skills/book-atlas/`.
3. **라우팅** — 스펙 §11 도입부: `**/*-atlas/_global/config.md` 글롭(node_modules·.git 제외), 1개→확인 후 활성화, 여러 개→선택, 없음+PDF→온보딩, 없음+PDF없음→질문.
4. **온보딩 절차** — 스펙 §11 온보딩 7단계를 순서 목록으로, 각 단계에 참조 문서·스크립트 명시 (`references/toc-pipeline.md`, `verify-offset.sh`, vault_name 질문, graph/ 설치, 훅 설치 여부 질문 — templates.md 의 훅 JSON 조각 사용).
5. **정리 세션 루프** — 스펙 §11 의 6단계. "시작 전에 반드시 읽는다: `note-rules.md`, `figures.md`. 새 챕터면 `toc-pipeline.md` 분할·병합 절." 명시.
6. **가벼운 확인 / 그래프 갱신** — 스펙 §11 마지막 두 절.
7. **하드 룰 10개** — 스펙 §12 를 그대로 복사.
8. **언어 규칙** — 대화·본문 사용자 언어, 파일명·슬러그 영어 kebab-case, H2 리터럴 고정.
9. **셀프 리뷰 체크리스트** — 세션 완료 선언 전: check-note/check-chapter exit 0 확인 · build-graph 실행 · 경고 리포트 처리 · coverage 갱신 · 진행 표 갱신 · 구분자 아래 안 건드림 · pdftotext -layout.
10. **참조 파일 표** — 5개 references + 언제 읽는가.

- [ ] **Step 6: Commit** — `feat(book-atlas): SKILL.md + PostToolUse 훅 (+2케이스)`

---

### Task 9: install/uninstall · README · 최종 검증

**Files:**
- Create: `install.sh`, `uninstall.sh`, `README.md`

**Interfaces:**
- Consumes: 전체 패키지.
- Produces: `./install.sh` → `~/.claude/skills/book-atlas/` 설치.

- [ ] **Step 1: install.sh / uninstall.sh**

```bash
#!/usr/bin/env bash
# install.sh — book-atlas 를 ~/.claude/skills/ 에 설치한다
set -euo pipefail
SRC="$(cd "$(dirname "$0")/skills/book-atlas" && pwd)"
DST="$HOME/.claude/skills/book-atlas"
mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"
echo "installed: $DST"
```

```bash
#!/usr/bin/env bash
# uninstall.sh
set -euo pipefail
rm -rf "$HOME/.claude/skills/book-atlas"
echo "removed: ~/.claude/skills/book-atlas"
```

- [ ] **Step 2: README.md** — 절: 무엇을 하는 스킬인가(3문장) · 설치/제거 · 사용 흐름(온보딩→정리→그래프 스크린샷 자리) · vault 구조 트리(스펙 §2 요약) · deep-tutor 와의 관계(정리는 book-atlas, 인출은 deep-tutor) · 스펙·계획 문서 링크.
- [ ] **Step 3: 최종 전체 테스트**

Run: `skills/book-atlas/scripts/tests/run-tests.sh` → 기대: `pass=17 fail=0`
Run: `bash -n install.sh uninstall.sh skills/book-atlas/scripts/*.sh` → 기대: 문법 오류 0
Run: `./install.sh && ls ~/.claude/skills/book-atlas/SKILL.md` → 기대: 존재

- [ ] **Step 4: 패키지 트리 대조** — `find skills/book-atlas -type f | sort` 를 스펙 §14 트리와 눈으로 대조. 누락·잉여 없음 확인.
- [ ] **Step 5: Commit** — `feat(book-atlas): install/uninstall + README — 패키지 완성`

---

## 계획 밖 — 실전 검증 (사용자와 함께)

패키지 완성 후 실제 원서 PDF 로 첫 온보딩 세션을 돌린다: 목차 추출→manifest 확인→1개 챕터 정리→그래프 확인. 이는 사용자의 PDF 와 판단이 필요하므로 태스크가 아니라 첫 사용 세션이다. 여기서 드러나는 파싱 실패·뷰어 어색함은 이슈로 받아 후속 수정한다.
