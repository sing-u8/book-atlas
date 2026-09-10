# 볼트 교정 실행 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원장 417행이 지시하는 교정을 볼트에 실제로 반영하고, 모든 행을 `reconcile.py` 로 닫는다.

**Architecture:** **원장이 명세다.** 이 계획은 무엇을 고칠지 열거하지 않는다 — 그건 `_global/fixes/ch01–07.md` 의 417행에 이미 자족적으로(원문 인용·조치·검증식까지) 적혀 있다. 이 계획이 정하는 것은 **순서와 닫는 방법**뿐이다. 단계마다 장별로 실행자를 보내고, 실행자는 자기 장의 해당 단계 행만 처리한 뒤 상태를 `적용` 으로 올리며, **`검증` 승격은 `reconcile.py` 만** 한다.

**Tech Stack:** Python 3 (표준 라이브러리) · bash 3.2 · `pdftotext`/`pdftoppm`

**Spec:** `docs/specs/2026-09-06-vault-remediation-design.md`

## Global Constraints

- 볼트 `~/Documents/StudyWithClaude/Designing_LLM/designing-llm-applications-atlas` (브랜치 `remediation`)
- 스킬 `~/Documents/claude-skill-set/book-atlas` (브랜치 `remediation-toolchain`)
- **PDF쪽 = 책쪽 + 22.** PDF 는 `_global/config.md` 의 `source_pdf`. 경로에 공백이 있으니 항상 따옴표
- **행 하나가 곧 지시다.** 실행자는 행의 `조치` 를 그대로 수행한다. 행이 시키지 않은 것을 하지 않는다
- **상태 전이**: 실행자는 `열림` → `적용` 까지만. `적용` → `검증` 은 `reconcile.py --promote` 만
- 원장 행의 **본문(무엇·근거·조치·검증)은 수정하지 않는다.** 상태 줄만 바꾼다.
  행 자체가 틀렸다고 판단되면 고치지 말고 **보고**한다(단계 끝의 조정 절차로 처리)
- `reconcile.py` 는 `--skill-root` 기본값이 스킬 저장소다. 플래그 없이 돌려도 된다
- 작업 단위마다 커밋한다. 커밋 메시지에 처리한 행 ID 범위를 적는다

## 원장 현황 (2026-09-06 기준)

| 장 | S | P | E | G | M |
|---|---:|---:|---:|---:|---:|
| ch01 | 3 | 20 | 4 | 12 | 16 |
| ch02 | 4 | 23 | 13 | 19 | 22 |
| ch03 | 4 | 12 | 4 | 15 | 3 |
| ch04 | 9 | 17 | 9 | 15 | 16 |
| ch05 | 11 | 26 | 11 | 16 | 10 |
| ch06 | 4 | 18 | 7 | 13 | 13 |
| ch07 | 11 | 16 | 3 | 6 | 5 |
| cross-chapter | | 1 | | | |
| skill | | | | | | (K6, 이미 `적용`)
| **계** | **46** | **133** | **51** | **96** | **85** |

현재: `열림 408 · 검증통과 7 · 실패 0 · 대상없음 0 · 수동 5 · 보류 2`

## 단계 순서 — 왜 이 순서인가

명세 §4 가 정한 순서다. **S(병합)가 마지막인 것이 핵심**이다.

원래 명세는 S 를 1단계에 뒀다. 근거는 "뒤의 모든 행이 참조할 파일명을 바꾼다" 였는데, 그것은 S 이후에
행이 만들어질 때 성립하는 논리다. 417행이 이미 다 있고 전부 현재 파일명을 가리키는 지금 S 를 먼저 하면
**자기 원장 42행을 스스로 무효화**한다 — 병합 예정 13편을 겨냥한 행이 P 13 · E·G·M 24 · **제거형 5** 다.

S 를 마지막에 두면 내용 수정을 자식 파일에서 하고, **병합이 그 고쳐진 텍스트를 부모 H3 로 그대로 옮긴다.**
재타깃이 필요 없고, 제거형 5개도 파일이 사라지기 전에 닫혀 거짓 통과가 안 생긴다.

**S 행은 세 종류다. 조치를 읽고 가른다.**
- **생성** — 노트를 새로 만든다(`(신설, …)` 표기). 아무것도 무효화하지 않으므로 **먼저**
- **편집** — `_coverage.md` 의 거짓 분할 사유를 다시 쓴다. 파일을 지우지 않으므로 **먼저**
- **삭제(병합)** — 자식을 부모 H3 로 흡수하고 파일을 지운다. **마지막**

---

### Task 1: S(생성·편집) — 노트 신설과 커버리지 사유 재작성

> 명세 §4 가 **`S(추가)`** 라 부르는 단계다. 실제로는 두 종류가 섞여 있어 계획에서는
> `생성·편집` 으로 쓴다 — 노트를 **만드는** 행과 `_coverage.md` 의 거짓 사유를 **고치는** 행.
> 공통점은 **아무 파일도 지우지 않아 기존 원장 행을 무효화하지 않는다**는 것이고, 그래서 먼저 온다.

**Files:**
- Modify: `{vault}/*/chapter-0[1-7]*/_coverage.md`
- Create: 원장이 `(신설, …)` 로 지목한 노트들
- Modify: `{vault}/_global/fixes/ch0[1-7].md` (상태 줄만)

**Interfaces:**
- Produces: 신설 노트가 존재하게 되어, 그것을 겨냥한 E·G 행이 Task 3–4 에서 실행 가능해진다

- [ ] **Step 1: 이 단계에서 처리할 행을 확정한다**

```bash
cd {vault}/_global/fixes
python3 - <<'PY'
import glob,re
for f in sorted(glob.glob('ch0[1-7].md')):
    for blk in re.split(r'\n(?=### )', open(f,encoding='utf-8').read()):
        m=re.match(r'### (\S+) · S · (.+?)\n', blk)
        if not m: continue
        act=re.search(r'- \*\*조치\*\*(.*?)(?=\n- \*\*검증\*\*)', blk, re.S)
        a=act.group(1) if act else ''
        kind='삭제(Task 6)' if '삭제' in a and '신설' not in m.group(2) else ('생성' if '신설' in m.group(2) else '편집')
        print(f"{m.group(1)}\t{kind}\t{m.group(2)[:50]}")
PY
```
Expected: 46행이 `생성`/`편집`/`삭제(Task 6)` 로 갈린다. **삭제로 분류된 것은 이 Task 에서 건드리지 않는다.**
분류가 애매한 행은 조치 전문을 읽고 판단해 목록에 근거를 적는다.

- [ ] **Step 2: 장별로 실행자를 보낸다 (7명, 병렬)**

각 실행자에게 주는 것: ①볼트 경로와 브랜치 ②담당 장 ③**그 장의 생성·편집 S행 ID 목록**
④"행의 `조치` 를 그대로 수행하고, 끝나면 그 행의 `- **상태** 열림` 을 `- **상태** 적용` 으로 바꿔라"
⑤"원장 행의 본문은 절대 고치지 마라. 행이 틀렸다고 판단되면 수행하지 말고 보고하라"
⑥"하위 에이전트를 띄우지 마라" ⑦"자기 장 밖 파일은 건드리지 마라. 단 조치가 명시적으로 지목한
다른 장의 링크 교정은 수행하라"

- [ ] **Step 3: 대조하고 승격한다**

```bash
cd {vault}/_global/fixes && python3 reconcile.py .
```
Expected: 이 단계 행들이 `검증 통과` 에 잡힌다. `검증 실패` 가 있으면 그 ID 를 해당 실행자에게
돌려보내 다시 하게 한다 — **실행자가 "했다" 고 해도 검증식이 통과해야 닫힌다.**

- [ ] **Step 4: 통과분을 닫는다**

```bash
cd {vault}/_global/fixes && python3 reconcile.py . --promote
```
Expected: `→ N건을 '검증' 으로 올렸다`

- [ ] **Step 5: 커밋**

```bash
cd {vault} && git add -A
git commit -m "fix(vault): S(생성·편집) 반영 — 노트 신설과 커버리지 사유 재작성"
```

---

### Task 2: P — 쪽 재기준화 133행

**Files:**
- Modify: 노트 125편의 frontmatter `pages:` · 본문 `p.NNN` 인용
- Modify: `{vault}/*/chapter-0[1-7]*/_coverage.md` 7개 (머리말 + 표)
- Modify: `{vault}/_global/config.md` (XC-001, 이미 `적용`)

**Interfaces:**
- Consumes: Task 1 의 신설 노트(그 노트에도 `pages:` 가 필요하다)
- Produces: `_coverage.md` 가 실제 판본 기준이 되어, **Task 7 의 게이트 두 개가 비로소 의미를 갖는다**
  (`check-chapter.sh` 의 연속성 검사와 `audit-delivery.py` 가 이 표에서 쪽을 읽는다)

- [ ] **Step 1: 장별로 실행자를 보낸다 (7명, 병렬)**

이 단계는 가장 크지만 가장 기계적이다. 각 행이 옛 값과 실제 값을 **둘 다** 적고 있다.
실행자에게 강조할 것: **행에 적힌 값을 그대로 쓴다.** PDF 를 다시 열어 재계산하지 않는다 —
그 값은 이미 재검수에서 실측·검증됐고, 다시 재면 불일치가 생긴다.

- [ ] **Step 2: 대조·승격·커밋** (Task 1 Step 3–5 와 동일한 절차)

- [ ] **Step 3: `_coverage.md` 가 실제로 새 기준이 됐는지 확인한다**

```bash
cd {vault}
grep -l "오프셋 0" */chapter-0[1-7]*/_coverage.md ; echo "---"
grep -h "^| [0-9]" part-1-llm-ingredients/chapter-03-*/_coverage.md | head -3
```
Expected: 첫 명령은 **출력 없음**(그 선언이 모두 사라짐). 둘째는 3장 표가 `69`–`86` 대역을 쓴다
(옛 `153`–`184` 가 아니라).

- [ ] **Step 4: 보강된 게이트를 처음으로 의미 있게 돌린다**

```bash
for d in {vault}/*/chapter-0[1-7]*; do
  bash {skill}/skills/book-atlas/scripts/check-chapter.sh "$d" 2>&1 | grep -E "FAIL|선언 구간"
done
```
Expected: 이제 실제 쪽 기준이므로 **선언 구멍이 새로 보고될 수 있다.** 보고되면 **고치지 말고
목록으로 남긴다** — 그것은 원장에 없는 새 발견이므로 Step 5 로 간다.

- [ ] **Step 5: 새 발견이 있으면 원장에 행을 추가한다**

Step 4 가 구멍을 냈다면, 그 장 원장에 `CH0N-301` 부터 행을 만든다(형식은 기존 행과 동일,
자족성 원칙 유지). **원장에 없는 수정을 하지 않는다** — 이 사슬은 원장에 들어온 것만 판정한다.
없으면 이 Step 은 건너뛴다.

---

### Task 3: E — 오류 51행

**Files:**
- Modify: 원장 E행이 지목한 노트들
- Modify: `{vault}/_global/fixes/ch0[1-7].md` (상태 줄만)

**Interfaces:**
- Consumes: Task 2 의 쪽 재기준화(E행 중 쪽 인용을 함께 고치는 것이 있다)

- [ ] **Step 1: 장별로 실행자를 보낸다 (7명, 병렬)**

E 는 **독자가 사실을 잘못 알게 되는 것**이다. 실행자에게 강조할 것:
- 행의 `근거` 에 **원문 인용이 들어 있다.** 그것을 기준으로 고친다. PDF 를 다시 열 필요가 없다
- 고친 문장이 **원문이 말하지 않는 것을 새로 주장하지 않도록** 한다. 원문이 애매하면 애매한 채로 둔다
- 노트의 다른 곳에 같은 오류가 반복되면(예: 한 서술이 4곳에 있다) **행이 지목한 곳을 전부** 고친다

- [ ] **Step 2: 대조·승격·커밋**

- [ ] **Step 3: 오류가 실제로 사라졌는지 표본 확인**

```bash
cd {vault}/_global/fixes && python3 reconcile.py . | head -8
```
Expected: `검증 실패 0`. 그리고 E행 3개를 무작위로 골라 그 노트를 직접 열어 **행이 시킨 대로만
바뀌었는지**(과잉 수정이 없는지) 눈으로 확인한다.

---

### Task 4: G — 보완필요 96행

**Files:**
- Modify: 원장 G행이 지목한 노트들
- Modify: `{vault}/_global/fixes/ch0[1-7].md` (상태 줄만)

**Interfaces:**
- Consumes: Task 1 의 신설 노트 · Task 2 의 쪽 기준

- [ ] **Step 1: 장별로 실행자를 보낸다 (7명, 병렬)**

**이 단계가 가장 무겁다.** G 는 "원문의 중요한 조각이 빠졌다" 이고, 상당수가 **새 PDF 에서 회수한
원문**(옛 판본이 잘라 먹어 노트가 알 수 없던 것)이다 — T5 코드 블록, `02g` 의 import 6줄,
표 5-2 의 라이선스 6행, Table 2-1 의 마지막 열, PII 정규식 등.

실행자에게 강조할 것:
- **회수한 원문을 그냥 붙여넣지 마라.** 노트의 작성 규칙(`{skill}/skills/book-atlas/references/note-rules.md`)을
  읽고 그 문체·구조에 맞춰 녹인다. 특히 규칙 7(원문 장문 복사 금지)과 규칙 11(근거 표시)
- 코드 블록은 **원문 그대로** 넣되, 원문 자체에 결함이 있으면(미정의 변수·안 닫힌 괄호·오탈자)
  그 사실을 노트에 적는다. 이 책에는 그런 자리가 여럿 있고 원장이 근거에 밝혀 뒀다
- 새 용어가 생기면 `_glossary.md` 에 등재한다. **같은 용어를 두 번 정의하지 않는다**

- [ ] **Step 2: 대조·승격·커밋**

- [ ] **Step 3: 노트 게이트를 돌린다**

```bash
for f in {vault}/*/chapter-0[1-7]*/[0-9]*.md; do
  bash {skill}/skills/book-atlas/scripts/check-note.sh "$f" >/dev/null || echo "FAIL $f"
done
```
Expected: 출력 없음. G 단계는 노트에 내용을 더하므로 도표·연결·용어 대조가 깨질 수 있다 —
깨지면 그 노트를 고친 실행자에게 돌려보낸다.

---

### Task 5: M — 사소 85행

**Files:**
- Modify: 원장 M행이 지목한 노트들
- Modify: `{vault}/_global/fixes/ch0[1-7].md` (상태 줄만)

- [ ] **Step 1: 장별로 실행자를 보낸다 (7명, 병렬)**

M 은 표기·귀속의 미세한 어긋남이다. 상당수가 **원서 오탈자를 말없이 교정한 것**
(`Kullback-Liebler`·`bitsnbytes`·`Loshcilov`·`OpenAi`·`good:011` 등)이고, 조치는 대개
"원문 표기와의 차이" 를 밝히는 한 줄을 더하는 것이다.

- [ ] **Step 2: 대조·승격·커밋**

---

### Task 6: S(병합) — 자식 13편을 부모로 흡수

**Files:**
- Modify: 부모 노트들 (H3 흡수)
- Delete: 병합 대상 자식 노트 13편
- Modify: 볼트 전역의 `[[자식]]` 링크 · `_glossary.md` 의 "처음 나온 곳" · `_coverage.md` · `_chapter.md`
- Modify: `{vault}/_global/fixes/ch0[1-7].md` (상태 줄만)

**Interfaces:**
- Consumes: Task 3–5. **자식 노트의 내용이 이미 교정된 상태여야 한다** — 병합이 그 교정된 텍스트를
  부모로 옮기기 때문이다

- [ ] **Step 1: 병합 전에 그 자식들을 겨냥한 행이 전부 닫혔는지 확인한다**

```bash
cd {vault}/_global/fixes
python3 - <<'PY'
import glob,re
merged = {"02a-what-capabilities-need-what-data","02b-is-data-running-out",
"03a-major-datasets-one-by-one","03b-choosing-among-datasets",
"05a1-extracting-text-from-raw-web-documents","05a2-quality-and-language-filters",
"01a-what-a-vocabulary-is","01b-why-words-fail-as-units",
"02a-what-a-tokenizer-does","02b-comparing-tokenizers",
"01c1-what-open-actually-means","03a1-the-dataset-landscape","03a2-flan-and-template-design"}
open_rows=[]
for f in sorted(glob.glob('ch0[1-7].md')):
    for blk in re.split(r'\n(?=### )', open(f,encoding='utf-8').read()):
        m=re.match(r'### (\S+) · ([SPKEGM]) · (\S+)', blk)
        if not m: continue
        if m.group(3).replace('.md','') in merged and m.group(2)!='S':
            st=re.search(r'- \*\*상태\*\* (.+)', blk)
            if st and st.group(1).strip() not in ('검증',): open_rows.append((m.group(1),m.group(2),st.group(1).strip()))
print(f"병합 대상을 겨냥한 미종결 행 {len(open_rows)}건")
for r in open_rows: print("   ",r)
PY
```
Expected: **0건.** 하나라도 남으면 Task 3–5 로 돌아간다 — 파일이 사라진 뒤에는 그 행을 정직하게
닫을 방법이 없다(그래서 `reconcile.py` 가 `대상 없음` 으로 막는다).

- [ ] **Step 2: 병합에 딸린 P행을 무효 처리한다**

병합되는 13편의 `pages:` 를 고치는 P행은 파일이 사라지므로 의미가 없다. **조용히 버리지 말고**
상태를 `보류(병합으로 소멸 — CH0N-2NN 참조)` 로 바꾼다. 그러면 집계가 정직하게 유지된다.
(Task 2 에서 이미 `검증` 으로 닫혔다면 그대로 둔다 — 그 시점에는 실제로 수행됐기 때문이다.)

- [ ] **Step 3: 장별로 실행자를 보낸다 (병합이 있는 4개 장: ch02·ch03·ch05·ch06)**

각 S(삭제) 행의 조치에 파생 작업이 전부 적혀 있다 — H3 흡수 · 파일 삭제 · 볼트 전역 링크 재연결 ·
용어집 "처음 나온 곳" · `_coverage.md`·`_chapter.md` 갱신. **항목별로 하나씩 짚어가며** 적용하게 한다.

실행자에게 강조할 것:
- **부모가 껍데기가 되면 안 된다.** 흡수한 뒤에도 부모는 `note-rules.md` 의 부모 노트 규칙
  (정의로 열지 않기 · 왜 이렇게 나뉘는지 설명 · `check-note.sh` 통과)을 지켜야 한다
- 링크 재연결은 `[[부모]]`(앵커 없음)로 한다 — 볼트의 기존 병합 사례가 그 방식이라 일관성을 지킨다

- [ ] **Step 4: 대조하고, 안전장치가 작동하는지 확인한다**

```bash
cd {vault}/_global/fixes && python3 reconcile.py .
```
Expected: `대상 없음` 이 **0 이어야 한다.** 0이 아니면 Step 1 의 확인이 샌 것이다 — 그 ID 를
확인하고 왜 닫히지 않았는지 밝힌다. **이 확인이 이번 설계의 마지막 안전장치다.**

- [ ] **Step 5: 승격·커밋**

---

### Task 7: 최종 검증

**Files:** 수정 없음 (검증만)

- [ ] **Step 1: 원장이 전부 닫혔는가**

```bash
cd {vault}/_global/fixes && python3 lint-ledger.py . && python3 reconcile.py .
```
Expected: `lint-ledger: PASS` · `열림 0 · 검증 실패 0 · 대상 없음 0`.
`수동` 5건과 `보류` 는 남는다 — **수동 5건은 사람이 직접 확인하고** 결과를 원장에 적는다
(mermaid 도표 배치·화살표 방향 등 문자열로 판정할 수 없는 것들이다).

- [ ] **Step 2: 게이트 전량**

```bash
for d in {vault}/*/chapter-0[1-7]*; do bash {skill}/skills/book-atlas/scripts/check-chapter.sh "$d"; done
for f in {vault}/*/chapter-0[1-7]*/[0-9]*.md; do bash {skill}/skills/book-atlas/scripts/check-note.sh "$f" >/dev/null || echo "FAIL $f"; done
```
Expected: 챕터 게이트 전부 PASS · 노트 게이트 출력 없음.

- [ ] **Step 3: 인도 검사 — 이제 처음으로 의미가 있다**

```bash
for d in {vault}/*/chapter-0[1-7]*; do
  echo "== $(basename $d)"; python3 {skill}/skills/book-atlas/scripts/audit-delivery.py "$d" | head -3
done
```
Expected: `_coverage.md` 가 실제 판본 기준이 됐으므로 **비로소 유의미한 숫자**가 나온다.
명세 §8.3 의 잡음 상한(한 장 30건)을 여기서 판정한다 — 넘으면 후보 검출을 좁히고(들여쓰기 임계·
표제 조건), 두 번 조여도 안 되면 이 검사를 **보류**로 둔다. **이것이 R11·R13 이 미뤄 둔 판정이다.**

- [ ] **Step 4: 링크·용어집·그래프**

```bash
cd {vault}
python3 {skill}/skills/book-atlas/scripts/build-graph.py .
```
Expected: 경고 0. 그리고 볼트 전역 끊긴 위키링크 0 · 용어집 중복 슬러그 0 을 확인한다
(병합으로 링크가 대량 바뀌었으므로 이 확인이 중요하다).

- [ ] **Step 5: 명세 완료 정의 대조**

명세 §9 의 7개 항목을 하나씩 짚는다. 특히 **7항** — "원장이 이 명세의 각 절을 덮는가".
이 사슬은 있는 행만 보고 **없는 행에는 침묵하므로**(§11 이 그렇게 새어 나왔다), 이 대조를 사람이
한 번은 해야 완료다.

- [ ] **Step 6: 최종 커밋**

```bash
cd {vault} && git add -A && git commit -m "chore: 교정 완료 — 원장 417행 전량 종결"
```

---

## 이 계획이 다루지 않는 것

- **8~13장 정리.** 아직 시작하지 않았다. 보강된 게이트와 규약(축 5 포함)이 그 장들에서 처음부터 적용된다
- **브랜치 병합.** 두 저장소 모두 브랜치에 두기로 했다. 이 계획이 끝난 뒤 사용자가 정한다
- **지연 처리된 Minor 들.** `progress.md` 의 `(deferred)` 항목은 최종 검토가 "다음 계획으로 이월" 로
  분류한 것들이다. Task 7 Step 5 에서 다시 훑어 지금 고칠지 판단한다
