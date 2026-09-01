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

# Book Atlas — 원서 한 권을 목차 구조 그대로

> 목차가 있는 원서 한 권으로 저장소를 만들고, 절 단위로 정리하고, 책→챕터→절→개념의
> 연결을 3D 그래프로 본다.

## 핵심 철학

1. **정리가 본체다.** 이 스킬의 산출물은 나중에 원서 대신 읽을 수 있는 정리물이고,
   나머지 장치는 전부 그 정리물의 품질을 지키기 위해 있다.
2. **그래프는 노트의 파생물이다.** 저장소가 정본이고 `graph-data.js` 는 저장소를 훑어
   매번 통째로 다시 만들어지는 거울일 뿐이다 — 반대 방향은 없다.
3. **인출은 이 스킬의 몫이 아니다.** 반복 퀴즈·꼬리질문 사슬·막힘 추적을 원하는
   사용자는 `deep-tutor` 로 안내한다.

## `<book-atlas-root>` 해석

이 문서와 모든 참조 문서가 쓰는 `<book-atlas-root>` 는 설치 후에는
`~/.claude/skills/book-atlas/`, 이 저장소 안에서 실행할 때는 `skills/book-atlas/` 다
(호스트 분기 없음).

---

## 라우팅 (매 호출)

1. `**/*-atlas/_global/config.md` 글롭으로 기존 저장소를 찾는다
   (`node_modules/`·`.git/` 제외).
   - **1개** → 사용자에게 확인받고 활성 저장소로 삼는다.
   - **여러 개** → 후보를 보여주고 고르게 한다.
2. **저장소 없음 + CWD 에 PDF 있음** → 아래 **온보딩**. 사용자가 PDF 경로를 인자로
   주면 CWD 스캔 없이 그 파일을 온보딩 소스로 삼는다 (경로가 존재하지 않으면 알리고
   다시 묻는다).
3. **저장소 없음 + PDF 없음** → 무엇을 정리할지 묻는다.

세션 작업을 시작하기 전에 활성 저장소 경로를 명시적으로 확인한다. 저장소가 활성화되면
기본 동작은 **정리 세션**이다 — 사용자가 가벼운 확인이나 그래프를 명시적으로 요청할
때만 아래 해당 절로 간다.

---

## 온보딩 (저장소 부트스트랩) — 7단계

1. **스캔본 검사** — 샘플 3쪽을 `pdftotext -layout` 으로 뽑아 본다. 스캔본이면
   **즉시 중단**하고 사유를 안내한다 — 이 스킬엔 돌아갈 개념 모드 폴백이 없다
   (`references/toc-pipeline.md` §2).
2. **목차 추출 → 계층 판정** — `toc-pipeline.md` §3 의 절차를 실제로 돌린다(미리
   짐작하지 않는다). 실패하면 같은 문서 §5 의 실패 분류·복구 절차를 밟고 다시
   시도한다. 즉시 중단하는 실패는 스캔본 하나뿐이다.
3. **오프셋 도출 → 검산** — `toc-pipeline.md` §4. 표본 **3개 모두 exit 0** 이어야
   그 구간의 오프셋을 확정한다.
   ```bash
   "<book-atlas-root>/scripts/verify-offset.sh" "<pdf>" <책쪽> <오프셋>
   ```
   하나라도 exit 2 면 **다른 오프셋을 추측해 재시도하지 않는다** — 멈추고 묻는다
   (하드 룰 2). exit 2 의 "빈 페이지" 메시지는 오프셋이 틀렸다는 증거가 아니라
   **재표본**하라는 뜻이다.
4. **`_global/source-manifest.md` 작성 → 사용자 확인** — 목차 트리와 구간별 오프셋
   표를 **사용자에게 보여주고 확인받은 뒤에** 다음 단계로 간다. 스키마는
   `references/templates.md` ②.
5. **언어·`vault_name` 질문 → `_global/config.md` 작성** — `vault_name` 은 자동
   추정하지 않고 **직접 묻는다**(틀리면 그래프의 모든 클릭이 조용히 실패한다).
   스키마는 `templates.md` ①.
6. **뼈대 생성 + 첫 빌드** — 목차 트리의 **전 챕터 디렉터리**를 한 번에 만들고,
   vault 루트에 빈 `_glossary.md` 스캐폴드와 `_assets/` 를 둔다(챕터마다 두지
   않는다). 그 뒤 `graph/` 를 설치하고 첫 빌드를 돌린다 —
   `config.md`·`source-manifest.md` 를 **먼저 쓴 뒤**여야 한다
   (`toc-pipeline.md` §8).
   ```bash
   mkdir -p "{book-slug}-atlas/graph/lib"
   cp "<book-atlas-root>/assets/graph.html"                "{book-slug}-atlas/graph/graph.html"
   cp "<book-atlas-root>/assets/lib/3d-force-graph.min.js" "{book-slug}-atlas/graph/lib/"
   python3 "<book-atlas-root>/scripts/build-graph.py" "{book-slug}-atlas"
   ```
   노트가 한 장도 없는 이 시점에도 그래프는 목차 뼈대(책→챕터)를 보여준다.
7. **PostToolUse 훅 설치 여부 질문** (선택) — 원하면 스킬이 직접 기록한다. 위치는
   **vault 안이 아니라 그것을 담은 프로젝트 루트**의 `.claude/settings.json` 이고,
   JSON 조각은 `templates.md` ⑧ 그대로다(`matcher: Write|Edit` →
   `<book-atlas-root>/scripts/check-note-hook.sh`). 파일이 이미 있으면
   **병합**한다 — 덮어쓰지 않고, 같은 `command` 항목이 있으면 중복 추가하지 않는다.

---

## 정리 세션 (기본 루프) — 6단계

1. **위치 확인** — `_global/config.md` 의 진행 위치 표를 읽고 이번 단위(챕터 또는
   이어서 할 절)를 확정한다. `source-manifest.md` 도 다시 읽되 `사용자수정` 행은
   재파싱 제안 대상에서 뺀다(하드 룰 3).
2. **새 챕터면** — `_coverage.md` 를 만들고 표 1의 **왼쪽 세 열**(책 쪽·PDF 쪽·원문
   절)을 먼저 채운다 → 그 **직후, 노트를 하나라도 쓰기 전에**
   `toc-pipeline.md` §9 의 **분할·병합 규칙**을 적용한다(어느 스크립트도 검사하지
   않는다 — 이 시점을 놓치면 규칙이 실행되는 자리가 없다) → `_chapter.md` 뼈대를
   만든다.
3. **절 노트 작성** — **시작 전에 반드시 읽는다: `references/note-rules.md`(작성 규칙
   12개)와 `references/figures.md`(도표 판단·형식·추출).** 규칙을 기억에 의존해
   어림짐작하지 않는다. 원문은 오프셋을 manifest 에서 읽어 이렇게 뽑는다(매번
   계산하지 않는다):
   ```bash
   pdftotext -layout -f <시작PDF쪽> -l <끝PDF쪽> "<pdf>" -
   ```
4. **용어집 등재 → 노트 게이트** — 새로 나온 전문어를 `_glossary.md` 에 등재하고
   (같은 용어를 두 번 정의하지 않는다) 게이트를 돌린다.
   ```bash
   "<book-atlas-root>/scripts/check-note.sh" <노트경로>
   ```
   exit 2 면 stderr 의 `FAIL` 목록을 고치고 **다시 실행**한다. 통과한 뒤에야
   frontmatter `status: done` 이고, `_coverage.md` 의 `정리 노트`·`상태` 칸을
   갱신한다(`부분`·`미반영` 뒤에는 `— 사유` 를 붙인다).
5. **챕터 완결 시** — `_chapter.md` 를 완성한다(필수 요소 5개: `templates.md` ④).
   **챕터 개요의 `## 읽는 순서` 흐름도는 노드 수와 무관하게 항상 mermaid flowchart
   로 그린다** — `figures.md` §4 의 형식 선택 규칙(무엇을 그리는가에 따라
   Mermaid/ASCII)은 **노트 본문 도표**에 적용되고, 챕터 개요의 흐름도는
   `templates.md` ④ 가 "노트 사이 의존 순서를 보여주는 mermaid flowchart" 로
   형식을 못박은 **별도 계약**이다. 그 뒤 챕터 게이트를 돌린다.
   ```bash
   "<book-atlas-root>/scripts/check-chapter.sh" <챕터경로>
   ```
   exit 0 을 확인한 뒤에만 `config.md` 진행 표를 `완료` 로 바꾼다.
6. **세션 종료 리추얼** — 아래. 빠뜨리고 세션을 끝내지 않는다.

### 세션 종료 리추얼 (하드 룰 10)

정리 세션은 예외 없이 이 세 가지로 끝난다.

1. **빌드한다.**
   ```bash
   python3 "<book-atlas-root>/scripts/build-graph.py" <vault-root>
   ```
   성공하면 stdout 이 조용하다. 경고가 있어도 exit 0 이다 — 빌더는 게이트가 아니라
   리포터다.
2. **경고 리포트를 처리한다.** stderr 의 `경고: ` 줄을 전부 읽고 대응한다 — 4종의
   뜻과 각각의 대응은 `references/graph.md` §2. 지금은 정상인 경고라면(예: 아직 안
   쓴 노트를 가리키는 커버리지 링크) 왜 정상인지 사용자에게 한 줄로 말한다.
3. **안내한다.** 사용자에게 "`graph/graph.html` 을 새로고침하세요"라고 알리고,
   `config.md` 의 진행 위치 표를 갱신한다.

---

## 가벼운 확인 (요청 시)

최근 정리한 절의 `## 스스로 확인` 질문을 던지고 가볍게 피드백한다. **막힘을 추적하거나
기록하지 않는다** — 이 스킬에는 gap 파일도 세션 로그도 없다. 사용자가 본격 인출
훈련(반복 퀴즈·꼬리질문 사슬·약점 추적)을 원하면 `deep-tutor` 를 안내한다.

## 그래프 갱신·열기 (요청 시)

`build-graph.py` 를 다시 돌리고 여는 법을 안내한다.

```bash
open "{book-slug}-atlas/graph/graph.html"
```

그래프가 비어 보이거나 Obsidian 클릭이 안 되면 `graph.md` §2(그래프가 비어 보일 때)와
§4(Obsidian 클릭이 안 될 때)의 진단 표를 본다.

---

## 하드 룰 (NEVER)

이 규칙들은 기본적인 도움 본능보다 우선한다. 어기려는 자신을 발견하면 멈춘다.

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

## 언어 규칙

- **사용자와의 대화** — 사용자의 감지된 언어.
- **파일 본문** — 스킬이 쓰든 사용자가 쓰든 사용자의 감지된 언어(`config.md` 의
  `language`).
- **파일명·디렉터리명·개념 슬러그** — 항상 영어 kebab-case. 챕터 디렉터리와 노트
  번호 접두는 0패딩 2자리(`chapter-01-`, `01-`). 책 제목이 한국어면 로마자 표기를
  자동으로 만들지 않고 슬러그를 사용자에게 묻는다(`toc-pipeline.md` §8).
- **기계가 리터럴로 대조하는 문자열은 로컬라이즈하지 않는다.** 번역하는 순간 게이트나
  그래프 빌드가 조용히 어긋난다.

| 리터럴 | 읽는 쪽 |
|---|---|
| 절 노트 필수 H2 6개 — `## 한눈에 보기` · `## 왜 이 절인가` · `## 본문 정리` · `## 개념` · `## 연결` · `## 스스로 확인` | `check-note.sh` |
| 구분자 `<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->` 와 그 아래 `## 내 메모` | `check-note.sh` · `build-graph.py` |
| `_coverage.md` 표 1의 마지막 열 헤더 `상태`, `정리 노트` 열 이름, 상태값 `반영`·`부분`·`미반영` | `check-chapter.sh` |
| `source-manifest.md` 의 `## 목차 트리` 헤딩과 표 왼쪽 네 열 순서(`계층·번호·제목·슬러그`) | `build-graph.py` |
| frontmatter 7키 이름, `config.md`·`source-manifest.md` 의 `- key: value` 키 이름 | `check-note.sh` · `build-graph.py` |

---

## 셀프 리뷰 (세션을 "완료"라고 말하기 전에)

- [ ] 새로 쓰거나 크게 고친 노트가 전부 `check-note.sh` **exit 0** 이었다
- [ ] 챕터를 완료로 선언했다면 `check-chapter.sh` 가 **exit 0** 이었다 (노트 게이트
      통과는 노트 한 장의 구조만 보증한다 — 원문을 담았는지는 다른 검사다)
- [ ] `build-graph.py` 를 돌렸다 (하드 룰 10)
- [ ] 빌드 경고를 하나씩 읽고 처리했다 — 남긴 경고는 왜 지금 정상인지 말했다
- [ ] `_coverage.md` 의 `정리 노트`·`상태` 칸을 이번에 쓴 노트만큼 갱신했다
      (`부분`·`미반영` 에는 `— 사유` 를 붙였다)
- [ ] `config.md` 의 진행 위치 표를 갱신했다
- [ ] 구분자 아래를 한 글자도 건드리지 않았다
- [ ] `pdftotext` 를 항상 `-layout` 과 함께 불렀다
- [ ] "`graph/graph.html` 을 새로고침하세요"를 안내했다

하나라도 어긋나면 완료를 보고하기 전에 고친다.

---

## 참조 파일

| 파일 | 언제 읽는가 |
|---|---|
| `references/toc-pipeline.md` | 온보딩 전체 — 정리 가능 판정(§2) · 목차 추출(§3) · 오프셋 검산(§4) · 실패 복구(§5) · 디렉터리 생성과 `graph/` 설치(§8). 그리고 **새 챕터에 들어갈 때** 분할·병합 규칙(§9) |
| `references/templates.md` | 저장소 안의 파일을 **하나라도 만들기 전** — 7종 스키마(①config ②manifest ③절 노트 ④`_chapter.md` ⑤`_coverage.md` ⑥`_glossary.md` ⑦구분자)와 ⑧ 훅 설정 JSON |
| `references/note-rules.md` | 절 노트 본문을 **한 줄이라도 쓰기 전**, 그리고 이미 쓴 노트를 보강하기 전 — 작성 규칙 12개(위반/교정 쌍)와 완료 게이트 |
| `references/figures.md` | 도표 자리를 쓰기 **직전** — 재현이냐 추출이냐(§2) · 재현 골격 8종(§3) · 형식 선택(§4) · `extract-figure.sh` 추출 절차(§5) |
| `references/graph.md` | 온보딩의 `graph/` 설치·첫 빌드, 세션 종료 리추얼의 경고 처리(§2), 뷰어 조작(§3), 그래프가 비어 보이거나 Obsidian 클릭이 안 될 때(§2·§4) |

## 번들 스크립트

전부 `<book-atlas-root>/scripts/` 아래에 있고, 검사 스크립트 셋은 종료코드 계약이
같다 — **0 통과 · 2 검사 실패(사유는 stderr) · 1 사용법·입력 오류**.

| 스크립트 | 호출 형태 |
|---|---|
| `check-note.sh` | `check-note.sh <노트경로>` — 절 노트 완료 게이트 |
| `check-chapter.sh` | `check-chapter.sh <챕터경로>` — 챕터 완결 게이트 |
| `check-note-hook.sh` | PostToolUse 훅 래퍼. 스킬이 직접 부르지 않는다 — 호스트가 stdin 으로 넘긴 JSON 을 읽어 대상 노트면 `check-note.sh` 를 돌린다 |
| `verify-offset.sh` | `verify-offset.sh <pdf> <책쪽> <오프셋>` — 쪽 오프셋 왕복 검산 |
| `extract-figure.sh` | `extract-figure.sh <pdf> <PDF쪽> <label> <out-dir>` — 도표 추출(0 성공 / 1 실패 → 재현으로 폴백) |
| `build-graph.py` | `python3 build-graph.py <vault-root>` — `graph/graph-data.js` 재생성(0 생성 완료, 경고가 있어도 0 / 1 vault 루트가 아님) |
