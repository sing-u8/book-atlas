# 볼트 교정 도구사슬 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 볼트 교정에 쓸 원장 도구(형식 검사·대조)와 스킬 게이트 보강을 만들고, 2~7장 재검수를 띄워 원장을 채운다.

**Architecture:** 원장은 마크다운 블록 형식이고 파싱이 잦아 원장 도구 둘은 Python 으로 쓴다(명세는 `.sh` 로 적었으나 bash 3.2 에 연상 배열이 없어 기존 스크립트도 같은 제약을 주석으로 남기고 있다 — 이름만 `.py` 로 바꾼 의도적 이탈이다). 게이트 보강은 기존 `check-*.sh` 를 고쳐 종료코드 계약(0/2/1)을 유지한다. 인도 검사는 오탐 위험이 커서 **경고 전용 별도 스크립트**로 분리한다.

**Tech Stack:** Python 3 (표준 라이브러리만) · bash 3.2 호환 · `pdftotext`/`pdftoppm` (poppler)

**Spec:** `docs/specs/2026-09-06-vault-remediation-design.md`

## Global Constraints

- 볼트 경로 `/Users/singyupark/Documents/StudyWithClaude/Designing_LLM/designing-llm-applications-atlas`
- 스킬 저장소 `/Users/singyupark/Documents/claude-skill-set/book-atlas` · 설치본 `~/.claude/skills/book-atlas`
- **PDF쪽 = 책쪽 + 22.** PDF 는 `_global/config.md` 의 `source_pdf` 에서 읽는다. 경로에 공백이 있으니 항상 따옴표로 감싼다
- 검사 스크립트 종료코드 계약: **0 통과 · 2 검사 실패(사유는 stderr) · 1 사용법·입력 오류**
- Python 은 표준 라이브러리만. 외부 패키지 설치 금지
- bash 스크립트는 **배열 사용 금지**(bash 3.2 호환). 기존 스크립트 관례를 따른다
- 원장 행 형식은 명세 §3.3 고정. 헤더 `### {ID} · {단계} · {대상}`, 본문 `- **{키}** {값}` 다섯 줄
- 단계 태그는 `S P K E G M` 여섯 개뿐. 상태는 `열림 적용 검증 보류(...)` 넷뿐
- **볼트 노트를 수정하는 작업은 이 계획에 없다.** 이 계획은 도구와 게이트만 만든다
- 아래 세 자리표시자는 이 경로를 뜻한다. 계획 본문에서 그대로 치환해 쓴다
  - `{vault}` = `/Users/singyupark/Documents/StudyWithClaude/Designing_LLM/designing-llm-applications-atlas`
  - `{skill}` = `/Users/singyupark/Documents/claude-skill-set/book-atlas`
  - `{fixes}` = `{vault}/_global/fixes` — 원장과 그 도구가 사는 곳. **재검수 산출물도 여기 보존돼 있다**
    (`_source-reaudit-ch01.md` 1장 재검수 · `_source-audit-2026-09-05.md` 옛 감사 190건 ·
    `_source-machine-2026-09-05.md` 기계검증 · `_reaudit-protocol.md` 규약 · `_reaudit-state.md` 기준)

## 이 계획의 범위

명세는 재검수(0) → 구조(S) → 쪽(P) → 스킬(K) → 내용(E·G·M) → 최종검증의 6단계를 정의한다.
그중 **S·P·E·G·M 은 이 계획에 넣을 수 없다** — 무엇을 고칠지가 아직 없기 때문이다. 그 내용은
0단계(재검수)가 원장에 써 넣는다. 없는 데이터를 두고 단계를 쓰면 전부 플레이스홀더가 된다.

따라서 이 계획은 **도구사슬 + 0단계 착수**까지다. 원장이 채워지면 그것을 입력으로 두 번째
계획(교정 실행)을 쓴다.

---

### Task 1: 원장 형식 검사 `lint-ledger.py`

**Files:**
- Create: `{vault}/_global/fixes/lint-ledger.py`
- Create: `{vault}/_global/fixes/tests/fixtures/good.md`
- Create: `{vault}/_global/fixes/tests/fixtures/bad-missing-field.md`
- Create: `{vault}/_global/fixes/tests/fixtures/bad-dup-id.md`
- Create: `{vault}/_global/fixes/tests/fixtures/bad-status.md`
- Create: `{vault}/_global/fixes/tests/fixtures/bad-syntax.md`
- Create: `{vault}/_global/fixes/tests/fixtures/bad-not-selfcontained.md`
- Create: `{vault}/_global/fixes/tests/run-tests.sh`

**Interfaces:**
- Produces: `parse_ledger(path) -> list[dict]` — 각 dict 는 키 `id phase target 무엇 근거 조치 검증 상태 line`. Task 2 가 그대로 임포트해 쓴다.
- Produces: CLI `lint-ledger.py <파일|디렉터리>` — 종료코드 0/2/1

- [ ] **Step 1: 픽스처 6개를 쓴다**

`tests/fixtures/good.md`:

```markdown
# 1장 원장

### CH01-001 · E · 05e-adversarial-prompting
- **무엇** 정렬 훈련 우회 메커니즘 설명이 원문에 없다
- **근거** 책 p.21 (PDF 43) — "as of today, alignment training provides only a weak
  layer of security, as it can be bypassed by cleverly prompting the LLM"
- **조치** 「한눈에 보기」 17행 · 도표 캡션 43행 · 「연결」 66행 · 「스스로 확인」 70행에서
  "표현 패턴에 반응하기 때문에" 라는 인과 서술을 삭제한다. 책은 왜 약한지 설명하지 않는다.
- **검증** `! grep -q "표현 패턴에 반응" 05e-adversarial-prompting.md`
- **상태** 열림

### XC-001 · E · _glossary.md
- **무엇** rag 항목이 용어집에 없다
- **근거** 책 p.32 (PDF 54) — "The PDF chatbot follows a paradigm called
  retrieval-augmented generation (RAG)."
- **조치** `_glossary.md` 에 `## rag (retrieval-augmented generation)` 항목을 만들고
  처음 나온 곳을 `[[09-from-prototype-to-production]]` 으로 적는다.
- **검증** `grep -q "^## rag " _glossary.md`
- **상태** 열림
```

`tests/fixtures/bad-missing-field.md` — `조치` 줄이 없다:

```markdown
### CH02-001 · G · 05b-selecting-quality-documents
- **무엇** KenLM 실습 코드가 없다
- **근거** 책 p.52 (PDF 74) — "KenlmModel.from_pretrained"
- **검증** `grep -q "KenlmModel" 05b-selecting-quality-documents.md`
- **상태** 열림
```

`tests/fixtures/bad-dup-id.md` — 같은 ID 가 두 번:

```markdown
### CH03-001 · E · 04-summary
- **무엇** 파이프라인을 3단계라 적었다
- **근거** 책 p.77 (PDF 99) — "composed of four components"
- **조치** 「한눈에 보기」 21행을 네 단계로 고친다.
- **검증** `! grep -q "3단계" 04-summary.md`
- **상태** 열림

### CH03-001 · M · 03f-special-tokens
- **무엇** 여덟 조각이라 쓰고 일곱 개만 나열한다
- **근거** 책 p.85 (PDF 107)
- **조치** 23행의 개수를 맞춘다.
- **검증** `! grep -q "여덟 조각" 03f-special-tokens.md`
- **상태** 열림
```

`tests/fixtures/bad-status.md` — 상태가 `진행중`:

```markdown
### CH04-001 · E · 03a-self-attention
- **무엇** 어텐션 정식을 책에 없다고 단정했다
- **근거** 책 p.114 (PDF 136) Figure 4-4 에 실려 있다
- **조치** 68·70행의 "책의 이 절에는 등장하지 않는 표기" 를 삭제한다.
- **검증** `! grep -q "등장하지 않는 표기" 03a-self-attention.md`
- **상태** 진행중
```

`tests/fixtures/bad-syntax.md` — 검증식 셸 구문 오류(따옴표가 안 닫힘):

```markdown
### CH05-001 · G · 03-loading-llms
- **무엇** 절 첫 문장이 빠졌다
- **근거** 책 p.137 (PDF 159) — "you need GPUs if you want acceptable text generation speeds"
- **조치** 「본문 정리」 맨 앞에 CPU/GPU 문장을 넣는다.
- **검증** `grep -q "GPU 가 필요하다 03-loading-llms.md`
- **상태** 열림
```

`tests/fixtures/bad-not-selfcontained.md` — 조치가 보고서를 참조:

```markdown
### CH06-001 · G · 02g-putting-it-all-together
- **무엇** full code 의 import 6줄이 없다
- **근거** 책 p.162 (PDF 184)
- **조치** 감사 보고 참조.
- **검증** `grep -q "from trl import SFTTrainer" 02g-putting-it-all-together.md`
- **상태** 열림
```

- [ ] **Step 2: 시험 러너를 쓴다**

`tests/run-tests.sh`:

```bash
#!/usr/bin/env bash
# lint-ledger.py 시험. 0 전부 통과 · 2 하나라도 실패
set -uo pipefail
cd "$(dirname "$0")"
LINT="../lint-ledger.py"
fail=0

expect() {  # expect <설명> <기대종료코드> <픽스처>
  python3 "$LINT" "fixtures/$3" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = "$2" ]; then
    echo "  ok   $1"
  else
    echo "  FAIL $1 — 기대 $2, 실제 $rc"; fail=1
  fi
}

expect "정상 원장은 통과"            0 good.md
expect "필수 필드 누락을 잡는다"      2 bad-missing-field.md
expect "ID 중복을 잡는다"            2 bad-dup-id.md
expect "잘못된 상태를 잡는다"         2 bad-status.md
expect "검증식 구문 오류를 잡는다"     2 bad-syntax.md
expect "자족성 위반을 잡는다"         2 bad-not-selfcontained.md

if [ "$fail" = 0 ]; then echo "run-tests: PASS"; else echo "run-tests: FAIL" >&2; fi
exit "$fail"
```

- [ ] **Step 3: 시험을 돌려 실패를 확인한다**

Run: `bash {vault}/_global/fixes/tests/run-tests.sh`
Expected: 여섯 줄 전부 `FAIL` — `lint-ledger.py` 가 아직 없어 python3 이 종료코드 2 가 아닌 값을 낸다

- [ ] **Step 4: `lint-ledger.py` 를 구현한다**

```python
#!/usr/bin/env python3
"""원장 형식 검사. 종료코드 0 통과 · 2 검사 실패 · 1 사용법 오류."""
import os
import re
import subprocess
import sys

HEADER = re.compile(r'^### (?P<id>(?:CH\d{2}|XC|SKILL)-\d{3}) · (?P<phase>[SPKEGM]) · (?P<target>\S.*?)\s*$')
FIELD = re.compile(r'^- \*\*(?P<key>무엇|근거|조치|검증|상태)\*\* ?(?P<val>.*)$')
REQUIRED = ('무엇', '근거', '조치', '검증', '상태')
STATUS_OK = re.compile(r'^(열림|적용|검증|보류\(.+\))$')
BANNED = ('감사 보고 참조', '감사 보고서 참조', '위 보고 참조', '앞선 보고 참조')


def parse_ledger(path):
    """원장 파일 하나를 행 목록으로 읽는다. 각 행은 dict."""
    rows, cur, key = [], None, None
    with open(path, encoding='utf-8') as fh:
        for n, raw in enumerate(fh, 1):
            line = raw.rstrip('\n')
            m = HEADER.match(line)
            if m:
                if cur:
                    rows.append(cur)
                cur = dict(m.groupdict(), line=n, file=path)
                key = None
                continue
            if cur is None:
                continue
            m = FIELD.match(line)
            if m:
                key = m.group('key')
                cur[key] = m.group('val').strip()
            elif key and line.startswith('  ') and line.strip():
                cur[key] = (cur[key] + ' ' + line.strip()).strip()
            elif line.startswith('### '):
                key = None
    if cur:
        rows.append(cur)
    return rows


def ledger_files(target):
    if os.path.isdir(target):
        return sorted(
            os.path.join(target, f) for f in os.listdir(target)
            if f.endswith('.md')
        )
    return [target]


def lint(target):
    problems = []
    seen = {}
    for path in ledger_files(target):
        text = open(path, encoding='utf-8').read().split('\n')
        # 헤더처럼 보이는데 형식이 틀린 줄
        for n, line in enumerate(text, 1):
            if line.startswith('### ') and not HEADER.match(line):
                problems.append(f"{path}:{n} 헤더 형식 오류 — {line.strip()}")
        for row in parse_ledger(path):
            rid = row['id']
            where = f"{row['file']}:{row['line']} {rid}"
            if rid in seen:
                problems.append(f"{where} ID 중복 — 앞서 {seen[rid]}")
            else:
                seen[rid] = where
            for k in REQUIRED:
                if not row.get(k):
                    problems.append(f"{where} 필수 필드 누락 — {k}")
            status = row.get('상태', '')
            if status and not STATUS_OK.match(status):
                problems.append(f"{where} 상태 값 오류 — {status}")
            action = row.get('조치', '')
            for bad in BANNED:
                if bad in action:
                    problems.append(f"{where} 자족성 위반 — 조치에 '{bad}'")
            verify = row.get('검증', '')
            if verify and verify != '수동':
                cmd = verify.strip('`')
                rc = subprocess.run(
                    ['bash', '-n', '-c', cmd],
                    capture_output=True, text=True,
                ).returncode
                if rc != 0:
                    problems.append(f"{where} 검증식 구문 오류 — {cmd}")
    return problems


def main(argv):
    if len(argv) != 2:
        print("usage: lint-ledger.py <원장파일|디렉터리>", file=sys.stderr)
        return 1
    target = argv[1]
    if not os.path.exists(target):
        print(f"lint-ledger: 대상이 없다: {target}", file=sys.stderr)
        return 1
    problems = lint(target)
    if problems:
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        print(f"lint-ledger: FAIL  {len(problems)}건", file=sys.stderr)
        return 2
    print("lint-ledger: PASS")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
```

- [ ] **Step 5: 시험을 돌려 통과를 확인한다**

Run: `bash {vault}/_global/fixes/tests/run-tests.sh`
Expected: 여섯 줄 전부 `ok`, 마지막 줄 `run-tests: PASS`, 종료코드 0

- [ ] **Step 6: 커밋**

```bash
cd {vault}
git add _global/fixes/
git commit -m "feat(fixes): 원장 형식 검사 lint-ledger.py + 시험 6종"
```

---

### Task 2: 원장 대조 `reconcile.py`

**Files:**
- Create: `{vault}/_global/fixes/reconcile.py`
- Modify: `{vault}/_global/fixes/tests/run-tests.sh` (시험 추가)
- Create: `{vault}/_global/fixes/tests/fixtures/reconcile-mixed.md`

**Interfaces:**
- Consumes: `parse_ledger(path)` from Task 1 (`lint_ledger` 모듈로 임포트)
- Produces: CLI `reconcile.py <원장파일|디렉터리> [--skill-root PATH] [--promote]`
  — `--promote` 없으면 읽기 전용. 종료코드 0/2/1

- [ ] **Step 1: 실행 위치 규칙을 확인한다**

명세 §3.3 의 표를 그대로 구현한다.

| ID 종류 | 검증식 실행 위치 |
|---|---|
| `CH{NN}-` | 볼트에서 `*/chapter-{NN}-*` 로 찾은 챕터 디렉터리 |
| `XC-` | 볼트 루트 |
| `SKILL-` | `--skill-root` (기본 `~/.claude/skills/book-atlas`) |

- [ ] **Step 2: 실패하는 시험을 쓴다**

`tests/fixtures/reconcile-mixed.md` — 네 가지 상태를 섞는다. 검증식은 픽스처 디렉터리에서
자족적으로 참/거짓이 되도록 `test` 명령을 쓴다.

```markdown
### XC-101 · E · _glossary.md
- **무엇** 통과하는 행
- **근거** 책 p.1 (PDF 23) — 시험용
- **조치** 없음. 시험용 행이다.
- **검증** `true`
- **상태** 적용

### XC-102 · E · _glossary.md
- **무엇** 적용이라 표시했으나 검증이 실패하는 행
- **근거** 책 p.1 (PDF 23) — 시험용
- **조치** 없음. 시험용 행이다.
- **검증** `false`
- **상태** 적용

### XC-103 · G · _glossary.md
- **무엇** 아직 열린 행
- **근거** 책 p.1 (PDF 23) — 시험용
- **조치** 없음. 시험용 행이다.
- **검증** `true`
- **상태** 열림

### XC-104 · M · _glossary.md
- **무엇** 수동 검증 행
- **근거** 책 p.1 (PDF 23) — 시험용
- **조치** 없음. 시험용 행이다.
- **검증** 수동
- **상태** 적용
```

`tests/run-tests.sh` 끝의 `if [ "$fail" = 0 ]` 앞에 추가:

```bash
echo "--- reconcile.py ---"
out=$(python3 ../reconcile.py fixtures/reconcile-mixed.md 2>&1); rc=$?
check() {  # check <설명> <기대문자열>
  if printf '%s' "$out" | grep -q "$2"; then echo "  ok   $1"; else echo "  FAIL $1 — '$2' 없음"; fail=1; fi
}
check "열림을 센다"          "열림 *1"
check "검증 통과를 센다"      "검증 통과 *1"
check "검증 실패를 센다"      "검증 실패 *1"
check "실패 ID 를 나열한다"    "XC-102"
check "수동 검증을 센다"      "수동 검증 *1"
if [ "$rc" = 2 ]; then echo "  ok   미해결이 있으면 종료코드 2"; else echo "  FAIL 종료코드 $rc"; fail=1; fi
```

- [ ] **Step 3: 시험을 돌려 실패를 확인한다**

Run: `bash {vault}/_global/fixes/tests/run-tests.sh`
Expected: `reconcile.py` 줄들이 전부 `FAIL` (파일이 아직 없다)

- [ ] **Step 4: `reconcile.py` 를 구현한다**

```python
#!/usr/bin/env python3
"""원장 대조. 검증식을 실행해 집계하고, --promote 면 적용→검증으로 올린다.
종료코드 0 미해결 없음 · 2 미해결 있음 · 1 사용법 오류."""
import argparse
import glob
import os
import re
import subprocess
import sys

# lint-ledger.py 는 파일명에 하이픈이 있어 일반 import 가 안 된다. 로더로 읽는다.
import importlib.util as _ilu

_spec = _ilu.spec_from_file_location(
    'lint_ledger', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lint-ledger.py'))
lint_ledger = _ilu.module_from_spec(_spec)
_spec.loader.exec_module(lint_ledger)
parse_ledger = lint_ledger.parse_ledger
ledger_files = lint_ledger.ledger_files


def vault_root(start):
    d = os.path.abspath(start)
    for _ in range(6):
        if os.path.isfile(os.path.join(d, '_glossary.md')):
            return d
        d = os.path.dirname(d)
    return None


def workdir(row, vault, skill_root):
    rid = row['id']
    if rid.startswith('XC-'):
        return vault
    if rid.startswith('SKILL-'):
        return skill_root
    m = re.match(r'^CH(\d{2})-', rid)
    if not m or vault is None:
        return None
    hits = glob.glob(os.path.join(vault, '*', f"chapter-{m.group(1)}-*"))
    return hits[0] if hits else None


def main(argv=None):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('target')
    ap.add_argument('--skill-root', default=os.path.expanduser('~/.claude/skills/book-atlas'))
    ap.add_argument('--promote', action='store_true')
    args = ap.parse_args(argv)

    if not os.path.exists(args.target):
        print(f"reconcile: 대상이 없다: {args.target}", file=sys.stderr)
        return 1

    vault = vault_root(args.target)
    open_rows, passed, failed, manual, held = [], [], [], [], []

    for path in ledger_files(args.target):
        for row in parse_ledger(path):
            status = row.get('상태', '')
            verify = row.get('검증', '').strip()
            if status.startswith('보류'):
                held.append(row)
                continue
            if status == '열림':
                open_rows.append(row)
                continue
            if verify == '수동':
                manual.append(row)
                continue
            cwd = workdir(row, vault, args.skill_root)
            if cwd is None or not os.path.isdir(cwd):
                failed.append((row, '실행 위치를 못 찾음'))
                continue
            rc = subprocess.run(
                ['bash', '-c', verify.strip('`')],
                cwd=cwd, capture_output=True, text=True,
            ).returncode
            (passed if rc == 0 else failed).append(row if rc == 0 else (row, f"종료코드 {rc}"))

    print(f"열림           {len(open_rows)}건")
    print(f"검증 통과       {len(passed)}건")
    print(f"검증 실패       {len(failed)}건")
    for row, why in failed:
        print(f"    {row['id']} · {row['target']} — {why}")
    print(f"수동 검증       {len(manual)}건")
    for row in manual:
        print(f"    {row['id']} · {row['target']}")
    print(f"보류           {len(held)}건")
    for row in held:
        print(f"    {row['id']} — {row['상태']}")

    if args.promote and passed:
        promote(passed)
        print(f"→ {len(passed)}건을 '검증' 으로 올렸다")

    return 2 if (open_rows or failed) else 0


def promote(rows):
    """상태 줄을 '적용' → '검증' 으로 바꾼다. reconcile 만 이 권한을 갖는다."""
    by_file = {}
    for row in rows:
        by_file.setdefault(row['file'], []).append(row['id'])
    for path, ids in by_file.items():
        lines = open(path, encoding='utf-8').read().split('\n')
        cur = None
        for i, line in enumerate(lines):
            m = lint_ledger.HEADER.match(line)
            if m:
                cur = m.group('id')
            elif cur in ids and line.strip() == '- **상태** 적용':
                lines[i] = '- **상태** 검증'
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 5: 시험을 돌려 통과를 확인한다**

Run: `bash {vault}/_global/fixes/tests/run-tests.sh`
Expected: 전부 `ok`, `run-tests: PASS`

- [ ] **Step 6: 승격이 실제로 파일을 고치는지 확인한다**

```bash
# 사본은 반드시 볼트 안에 둔다 — vault_root() 가 _glossary.md 를 위로 찾기 때문에
# /tmp 로 복사하면 실행 위치를 못 찾아 모든 행이 '검증 실패' 로 떨어진다
cd {vault}/_global/fixes
cp tests/fixtures/reconcile-mixed.md ./tmp-check.md
python3 reconcile.py ./tmp-check.md --promote
grep -A5 '^### XC-101' ./tmp-check.md | grep 상태   # → 검증
grep -A5 '^### XC-102' ./tmp-check.md | grep 상태   # → 적용 (그대로여야 한다)
rm -f ./tmp-check.md
```
Expected: 마지막 줄이 `- **상태** 검증` (XC-102 는 `적용` 그대로여야 한다)

- [ ] **Step 7: 커밋**

```bash
cd {vault}
git add _global/fixes/
git commit -m "feat(fixes): 원장 대조 reconcile.py — 승격 권한을 스크립트로 제한"
```

---

### Task 3: `check-chapter.sh` 선언 연속성 검사 (SKILL-001)

**Files:**
- Modify: `{skill}/skills/book-atlas/scripts/check-chapter.sh`
- Modify: `{skill}/skills/book-atlas/scripts/tests/run-tests.sh`

**Interfaces:**
- Consumes: `_coverage.md` 표 1 의 첫 열(책 쪽)
- Produces: 새 검사 항목 `선언 구간이 챕터를 덮음` — 실패 시 종료코드 2

- [ ] **Step 1: 쪽 범위 표기를 정규화하는 규칙을 정한다**

실제 표기 예: `346–347` · `358` · `284(상단)` · `371(14행)–375(11행)` · `360–365(상단)`
규칙 — 괄호 안 주석을 지우고, 남은 숫자 중 **첫 번째를 시작, 마지막을 끝**으로 삼는다.
`en dash(–)` 와 `hyphen(-)` 둘 다 구분자로 받는다.

- [ ] **Step 2: 실패하는 시험을 쓴다**

`{skill}/skills/book-atlas/scripts/tests/run-tests.sh` 에 추가:

```bash
# --- SKILL-001 선언 연속성 ---
tmp=$(mktemp -d)
mkdir -p "$tmp/vault/part-1/chapter-01-x"
printf 'book: x\n' > "$tmp/vault/_glossary.md"
cat > "$tmp/vault/part-1/chapter-01-x/_coverage.md" <<'EOF'
# Chapter 01 원문 커버리지

## 1. 원문 절 → 노트 매핑

| 책 쪽 | PDF 쪽 | 원문 절 | 정리 노트 | 상태 |
|---|---|---|---|---|
| 3–5 | 25–27 | A | [[01-a]] | 반영 |
| 8–10 | 30–32 | B | [[02-b]] | 반영 |
EOF
out=$(bash "$SCRIPTS/check-chapter.sh" "$tmp/vault/part-1/chapter-01-x" 2>&1) || true
if printf '%s' "$out" | grep -q '6–7'; then
  echo "  ok   선언 구멍(6–7쪽)을 잡는다"
else
  echo "  FAIL 선언 구멍을 못 잡는다"; fail=1
fi
rm -rf "$tmp"
```

- [ ] **Step 3: 시험을 돌려 실패를 확인한다**

Run: `bash {skill}/skills/book-atlas/scripts/tests/run-tests.sh`
Expected: `FAIL 선언 구멍을 못 잡는다`

- [ ] **Step 4: `check-chapter.sh` 에 검사를 추가한다**

기존 검사들 뒤, 최종 판정 앞에 넣는다. 배열을 쓰지 않는다(bash 3.2).

```bash
# --- 6) 선언 연속성 — coverage 구간이 챕터를 빈틈없이 덮는가 (SKILL-001) ---
# 표기 정규화: 괄호 주석 제거 → 남은 숫자의 첫/끝을 시작/끝으로.
# 예) "371(14행)–375(11행)" → 371 375 · "284(상단)" → 284 284
# coverage 가 없으면(검사 1 이 이미 실패시킴) ok 도 bad 도 찍지 않는다 —
# 아무것도 못 본 채 통과를 주장하지 않기 위해서다.
if [ -f "$COV" ]; then
gaps=""
prev_end=""
# 반드시 `## 1.` 절 안으로 한정한다. 파일 전체를 훑으면 `## 2. 코드·예제 커버리지`
# 표의 숫자 행까지 섞여 **거짓양성은 물론 거짓음성까지** 난다(표 2 에 그 쪽번호가
# 있으면 진짜 구멍이 조용히 통과한다).
ranges=$(awk '
    /^## 1\./ { insec=1; next }
    insec && /^## / { insec=0 }
    insec
  ' "$COV" \
  | grep -E '^\| *[0-9]' \
  | sed -e 's/|/\t/g' \
  | cut -f2 \
  | sed -e 's/([^)]*)//g' -e 's/[^0-9]\{1,\}/ /g' -e 's/^ *//' -e 's/ *$//' \
  | awk 'NF{ if (NF==1) print $1, $1; else print $1, $NF }' \
  | sort -n -k1,1)

while read -r s e; do
  [ -z "$s" ] && continue
  if [ -n "$prev_end" ]; then
    expect=$((prev_end + 1))
    if [ "$s" -gt "$expect" ]; then
      if [ "$s" -eq "$((expect + 1))" ]; then
        gaps="$gaps $expect"
      else
        gaps="$gaps $expect–$((s - 1))"
      fi
    fi
  fi
  [ -z "$prev_end" ] || [ "$e" -gt "$prev_end" ] && prev_end="$e"
done <<EOF
$ranges
EOF

if [ -n "$gaps" ]; then
  bad "선언 구간에 구멍:$gaps 쪽 — 어느 노트도 이 쪽을 선언하지 않는다"
else
  ok "선언 구간이 챕터를 덮음"
fi
fi   # [ -f "$COV" ]
```

- [ ] **Step 5: 시험을 돌려 통과를 확인한다**

Run: `bash {skill}/skills/book-atlas/scripts/tests/run-tests.sh`
Expected: `ok 선언 구멍(6–7쪽)을 잡는다`, 기존 17건도 그대로 통과

- [ ] **Step 6: 실제 볼트 1~7장에 돌려 회귀를 본다**

```bash
for d in {vault}/*/chapter-0[1-7]*; do
  echo "== $(basename $d)"; bash {skill}/skills/book-atlas/scripts/check-chapter.sh "$d" 2>&1 | grep -E 'FAIL|선언 구간'
done
```
Expected: 지금은 쪽 표기가 옛 판본이라 **구멍이 보고될 수 있다.** 이는 정상이며, P단계 이후
다시 돌려 0건이 되어야 한다. 보고된 구멍을 이 계획 밖 원장 행으로 넘기지 말고 목록만 기록한다.

- [ ] **Step 7: 커밋**

```bash
cd {skill}
git add skills/book-atlas/scripts/
git commit -m "feat(check-chapter): 선언 연속성 검사 — coverage 구간이 챕터를 덮는지 (SKILL-001)"
```

---

### Task 4: 인도 검사 `audit-delivery.py` (SKILL-001b)

**Files:**
- Create: `{skill}/skills/book-atlas/scripts/audit-delivery.py`

**Interfaces:**
- Consumes: 챕터 디렉터리 · `_global/config.md` 의 `source_pdf` 와 `page_offset`
- Produces: CLI `audit-delivery.py <챕터경로>` — **항상 종료코드 0**(사용법 오류만 1).
  세 갈래 목록을 stdout 으로 낸다: `언급됨` / `누락 의심` / `확인 불가`

- [ ] **Step 1: 검출 신호를 못박는다**

`pdftotext -layout` 출력의 왼쪽 여백이 층을 이룬다(명세 §8.3, 실측).

| 들여쓰기 | 정체 | 처리 |
|---:|---|---|
| 0칸, 짧고(≤60자) 마침표 없음 | **표제** | 후보 |
| 4~6칸 | 코드·프롬프트 예제 | 무시 |
| 15칸 이상 | **콜아웃·사이드바** | 후보 |
| `Figure N-M.` / `Table N-M.` | **캡션** | 후보 |

이 책의 콜아웃에는 `WARNING`·`NOTE` 텍스트 라벨이 **없다**(아이콘). 들여쓰기가 유일한 신호다.

- [ ] **Step 2: 구현한다**

```python
#!/usr/bin/env python3
"""인도 검사 — 노트가 선언한 구간의 표제·콜아웃·캡션을 노트가 언급하는지 본다.
경고 전용: 종료코드는 사용법 오류(1) 외에는 항상 0."""
import os
import re
import subprocess
import sys

CAPTION = re.compile(r'\b(Figure|Table) (\d+-\d+)\.')
ROW = re.compile(r'^\| *([0-9][^|]*) \|[^|]*\|[^|]*\| *(.+?) *\|')
LINK = re.compile(r'\[\[([^\]|#]+)')
STOP = {'the', 'and', 'for', 'that', 'this', 'with', 'from', 'are', 'not', 'you',
        'can', 'will', 'have', 'our', 'its', 'them', 'these', 'those', 'any'}


def config(vault):
    pdf, off = None, 0
    for line in open(os.path.join(vault, '_global', 'config.md'), encoding='utf-8'):
        if line.startswith('- source_pdf:'):
            pdf = line.split(':', 1)[1].strip()
        elif line.startswith('- page_offset:'):
            off = int(line.split(':', 1)[1].split('#')[0].strip())
    return os.path.normpath(os.path.join(vault, pdf)), off


def pages(spec):
    """'371(14행)–375(11행)' → (371, 375) · '284(상단)' → (284, 284)"""
    nums = re.findall(r'\d+', re.sub(r'\([^)]*\)', '', spec))
    if not nums:
        return None
    return int(nums[0]), int(nums[-1])


def extract(pdf, first, last):
    out = subprocess.run(
        ['pdftotext', '-layout', '-f', str(first), '-l', str(last), pdf, '-'],
        capture_output=True, text=True)
    return out.stdout.split('\n')


def candidates(lines):
    """(종류, 표시문자열, 탐침목록) 목록을 낸다."""
    found = []
    for line in lines:
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        text = line.strip()
        m = CAPTION.search(text)
        if m:
            found.append(('캡션', f"{m.group(1)} {m.group(2)}", [m.group(2)]))
            continue
        if indent >= 15:
            probes = [w for w in re.findall(r'[A-Z][\w.\-]{2,}|[a-z_]+\(\)|\d+[\w-]*', text)
                      if w.lower() not in STOP]
            if probes:
                found.append(('콜아웃', text[:60], probes[:4]))
            else:
                found.append(('콜아웃', text[:60], []))
        elif indent == 0 and len(text) <= 60 and not text.endswith('.') \
                and text[0].isupper() and len(text.split()) <= 7:
            found.append(('표제', text, [text]))
    # 같은 표시문자열이 이어지면 하나로 접는다(콜아웃은 여러 줄이다)
    merged, prev = [], None
    for kind, label, probes in found:
        if kind == '콜아웃' and prev and prev[0] == '콜아웃':
            prev[2].extend(probes)
            continue
        prev = [kind, label, list(probes)]
        merged.append(prev)
    return merged


def main(argv):
    if len(argv) != 2:
        print("usage: audit-delivery.py <챕터경로>", file=sys.stderr)
        return 1
    chdir = os.path.abspath(argv[1])
    vault = chdir
    for _ in range(4):
        vault = os.path.dirname(vault)
        if os.path.isfile(os.path.join(vault, '_glossary.md')):
            break
    else:
        print("audit-delivery: vault 루트를 못 찾음", file=sys.stderr)
        return 1

    pdf, off = config(vault)
    cov = os.path.join(chdir, '_coverage.md')
    if not os.path.isfile(cov):
        print(f"audit-delivery: _coverage.md 없음: {cov}", file=sys.stderr)
        return 1

    ok, miss, unknown = [], [], []
    for line in open(cov, encoding='utf-8'):
        m = ROW.match(line)
        if not m:
            continue
        rng, notecell = m.group(1), m.group(2)
        pg = pages(rng)
        if not pg:
            continue
        notes = LINK.findall(notecell)
        if not notes:
            continue
        body = ''
        for n in notes:
            p = os.path.join(chdir, n.strip() + '.md')
            if os.path.isfile(p):
                body += open(p, encoding='utf-8').read()
        if not body:
            continue
        lines = extract(pdf, pg[0] + off, pg[1] + off)
        for kind, label, probes in candidates(lines):
            if not probes:
                unknown.append((rng, kind, label))
            elif any(p in body for p in probes):
                ok.append((rng, kind, label))
            else:
                miss.append((rng, kind, label, probes[:3]))

    print(f"언급됨      {len(ok)}건")
    print(f"누락 의심   {len(miss)}건")
    for rng, kind, label, probes in miss:
        print(f"    p.{rng} [{kind}] {label}   탐침={probes}")
    print(f"확인 불가   {len(unknown)}건")
    for rng, kind, label in unknown:
        print(f"    p.{rng} [{kind}] {label}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
```

- [ ] **Step 3: 수용 시험 — 5장 WARNING 을 잡는가**

명세 §8.3. 옛 쪽 표기 그대로 돌리면 안 되므로, 시험용으로 5장 `_coverage.md` 를 건드리지 말고
그 한 행만 임시 파일로 만들어 돌린다.

```bash
cd /tmp && rm -rf dtest && mkdir -p dtest/part/chapter-05-x
V={vault}
cp "$V/_glossary.md" dtest/ 2>/dev/null || echo x > dtest/_glossary.md
mkdir -p dtest/_global && cp "$V/_global/config.md" dtest/_global/
cp "$V"/part-2-utilizing-llms/chapter-05-*/03-loading-llms.md dtest/part/chapter-05-x/
cat > dtest/part/chapter-05-x/_coverage.md <<'EOF'
| 책 쪽 | PDF 쪽 | 원문 절 | 정리 노트 | 상태 |
|---|---|---|---|---|
| 136–137 | 158–159 | Loading LLMs | [[03-loading-llms]] | 반영 |
EOF
python3 {skill}/skills/book-atlas/scripts/audit-delivery.py dtest/part/chapter-05-x
```
Expected: `누락 의심` 목록에 `[콜아웃] Do not trust evaluations performed by GPT-4…` 가 있다

- [ ] **Step 4: 수용 시험 — 3장 Postprocessing 을 잡는가**

```bash
cd /tmp && rm -rf dtest3 && mkdir -p dtest3/part/chapter-03-x
V={vault}
echo x > dtest3/_glossary.md
mkdir -p dtest3/_global && cp "$V/_global/config.md" dtest3/_global/
cp "$V"/part-1-llm-ingredients/chapter-03-*/03e-wordpiece.md dtest3/part/chapter-03-x/
cat > dtest3/part/chapter-03-x/_coverage.md <<'EOF'
| 책 쪽 | PDF 쪽 | 원문 절 | 정리 노트 | 상태 |
|---|---|---|---|---|
| 81–83 | 103–105 | WordPiece | [[03e-wordpiece]] | 반영 |
EOF
python3 {skill}/skills/book-atlas/scripts/audit-delivery.py dtest3/part/chapter-03-x
```
Expected: `누락 의심` 목록에 `[표제] Postprocessing` 이 있다

- [ ] **Step 5: 잡음 상한을 확인한다**

Run: 위 두 시험의 `누락 의심` + `확인 불가` 합계를 본다.
Expected: 한 행짜리 시험이므로 각각 30건 미만. **실제 챕터 전체로 돌렸을 때 30건을 넘으면**
명세 §8.3 대로 매칭 규칙을 조인다(탐침에서 흔한 단어를 더 뺀다). 두 번 조여도 안 되면 이
스크립트를 `보류` 로 두고 원장 `SKILL-001b` 행 상태를 `보류(잡음 과다)` 로 적는다.

- [ ] **Step 6: 커밋**

```bash
cd {skill}
git add skills/book-atlas/scripts/audit-delivery.py
git commit -m "feat(scripts): 인도 검사 audit-delivery.py — 선언 구간의 표제·콜아웃·캡션 대조 (SKILL-001b)"
```

---

### Task 5: `check-note.sh` 경로 붙은 위키링크 허용 (SKILL-002)

**Files:**
- Modify: `{skill}/skills/book-atlas/scripts/check-note.sh` (`resolve_term` 과 존재 검사)
- Modify: `{skill}/skills/book-atlas/scripts/tests/run-tests.sh`

**Interfaces:**
- Produces: `[[part-1-x/chapter-03-y/04-summary]]` 형태 링크가 게이트를 통과한다

- [ ] **Step 1: 실패하는 시험을 쓴다**

`{skill}/skills/book-atlas/scripts/tests/run-tests.sh` 에 추가:

```bash
# --- SKILL-002 경로 붙은 링크 ---
tmp=$(mktemp -d); mkdir -p "$tmp/v/p/chapter-03-y"
echo '## dummy' > "$tmp/v/_glossary.md"
printf '# 04\n' > "$tmp/v/p/chapter-03-y/04-summary.md"
cat > "$tmp/v/p/chapter-03-y/09-x.md" <<'EOF'
---
book: b
chapter: 3
section: "3.9"
title: x
pages: "책 p.1"
concepts: []
status: done
---
## 한눈에 보기
| 질문 | 핵심 답 |
|---|---|
| q | a |
## 왜 이 절인가
본문.
## 본문 정리
```text
도표
```
## 개념
없음.
## 연결
- [[p/chapter-03-y/04-summary]] — 3장 요약과 잇는다
- [[04-summary]] — 같은 폴더
## 스스로 확인
- q
<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->
## 내 메모
EOF
if bash "$SCRIPTS/check-note.sh" "$tmp/v/p/chapter-03-y/09-x.md" >/dev/null 2>&1; then
  echo "  ok   경로 붙은 링크를 통과시킨다"
else
  echo "  FAIL 경로 붙은 링크에서 게이트가 깨진다"; fail=1
fi
rm -rf "$tmp"
```

- [ ] **Step 2: 시험을 돌려 실패를 확인한다**

Run: `bash {skill}/skills/book-atlas/scripts/tests/run-tests.sh`
Expected: `FAIL 경로 붙은 링크에서 게이트가 깨진다`

- [ ] **Step 3: 존재 검사를 고친다**

`check-note.sh` 의 용어 존재 검사(`find "$VROOT" -name "$t.md"`)는 `t` 에 슬래시가 있으면
반드시 실패한다. 슬래시가 있으면 **경로로 직접 확인**하도록 분기한다.

```bash
    case "$t" in
      */*)
        # 경로 붙은 링크: vault 루트 기준 경로로 직접 확인한다.
        if [ -f "$VROOT/$t.md" ]; then
          continue
        fi
        # vault 루트 기준이 아니면 꼬리 조각으로 한 번 더 찾는다.
        if [ -n "$(find "$VROOT" -path "*/$t.md" -not -path '*/graph/*' 2>/dev/null)" ]; then
          continue
        fi
        ;;
      *)
        if [ -n "$(find "$VROOT" -name "$t.md" -not -path '*/graph/*' 2>/dev/null)" ]; then
          continue
        fi
        ;;
    esac
```

- [ ] **Step 4: 시험을 돌려 통과를 확인한다**

Run: `bash {skill}/skills/book-atlas/scripts/tests/run-tests.sh`
Expected: `ok 경로 붙은 링크를 통과시킨다` + 기존 시험 전부 통과

- [ ] **Step 5: 실제 볼트 회귀**

```bash
for f in {vault}/*/chapter-0[1-7]*/[0-9]*.md; do
  bash {skill}/skills/book-atlas/scripts/check-note.sh "$f" >/dev/null || echo "FAIL $f"
done
```
Expected: 출력 없음(125편 전부 통과)

- [ ] **Step 6: 커밋**

```bash
cd {skill}
git add skills/book-atlas/scripts/
git commit -m "fix(check-note): 경로 붙은 위키링크를 find -name 이 못 찾던 문제 (SKILL-002)"
```

---

### Task 6: `check-chapter.sh` basename 모호성 경고 (SKILL-003)

**Files:**
- Modify: `{skill}/skills/book-atlas/scripts/check-chapter.sh`
- Modify: `{skill}/skills/book-atlas/scripts/tests/run-tests.sh`

**Interfaces:**
- Produces: 경고 줄 `WARN 모호한 링크` — **종료코드는 바꾸지 않는다**(경고 전용)

- [ ] **Step 1: 실패하는 시험을 쓴다**

```bash
# --- SKILL-003 basename 모호성 ---
tmp=$(mktemp -d)
mkdir -p "$tmp/v/p/chapter-03-y" "$tmp/v/p/chapter-06-z"
echo '## d' > "$tmp/v/_glossary.md"
printf '# a\n' > "$tmp/v/p/chapter-03-y/04-summary.md"
printf '# b\n' > "$tmp/v/p/chapter-06-z/04-summary.md"
printf '# c\n\n[[04-summary]]\n' > "$tmp/v/p/chapter-06-z/01-x.md"
out=$(bash "$SCRIPTS/check-chapter.sh" "$tmp/v/p/chapter-06-z" 2>&1) || true
if printf '%s' "$out" | grep -q '모호한 링크'; then
  echo "  ok   모호한 basename 링크를 경고한다"
else
  echo "  FAIL 모호한 basename 을 경고하지 않는다"; fail=1
fi
rm -rf "$tmp"
```

- [ ] **Step 2: 시험을 돌려 실패를 확인한다**

Run: `bash {skill}/skills/book-atlas/scripts/tests/run-tests.sh`
Expected: `FAIL 모호한 basename 을 경고하지 않는다`

- [ ] **Step 3: 경고를 추가한다**

```bash
# --- 7) basename 모호성 경고 (SKILL-003) — 종료코드는 바꾸지 않는다 ---
# check-chapter.sh 에는 VROOT 가 없다. _glossary.md 를 위로 찾아 잡는다.
VROOT=""
_d="$DIR"
for _i in 1 2 3 4; do
  _d="$_d/.."
  if [ -f "$_d/_glossary.md" ]; then VROOT="$(cd "$_d" && pwd)"; break; fi
done
[ -n "$VROOT" ] || VROOT="$DIR"

for note in "$DIR"/*.md; do
  [ -f "$note" ] || continue
  grep -oE '\[\[[^]|#/]+\]\]' "$note" 2>/dev/null \
    | sed -e 's/^\[\[//' -e 's/\]\]$//' \
    | while read -r base; do
        [ -z "$base" ] && continue
        n=$(find "$VROOT" -name "$base.md" -not -path '*/graph/*' 2>/dev/null | wc -l | tr -d ' ')
        if [ "$n" -gt 1 ]; then
          echo "  WARN 모호한 링크 [[$base]] — 같은 이름 노트 ${n}개. 경로를 붙여라" >&2
        fi
      done
done | sort -u
```

- [ ] **Step 4: 시험을 돌려 통과를 확인한다**

Run: `bash {skill}/skills/book-atlas/scripts/tests/run-tests.sh`
Expected: `ok 모호한 basename 링크를 경고한다`

- [ ] **Step 5: 실제 볼트에서 알려진 3곳이 나오는지 본다**

```bash
for d in {vault}/*/chapter-0[1-7]*; do bash {skill}/skills/book-atlas/scripts/check-chapter.sh "$d" 2>&1 | grep '모호한 링크'; done | sort -u
```
Expected: `[[04-summary]]` 와 `[[08-summary]]` 가 나온다(감사에서 확인된 3곳의 원인)

- [ ] **Step 6: 커밋**

```bash
cd {skill}
git add skills/book-atlas/scripts/
git commit -m "feat(check-chapter): 같은 이름 노트로 인한 모호한 링크 경고 (SKILL-003)"
```

---

### Task 7: 문서 규칙 두 건 (SKILL-004 · SKILL-005)

**Files:**
- Modify: `{skill}/skills/book-atlas/references/toc-pipeline.md` (§9 분할 조건 · §4 오프셋)
- Modify: `{skill}/skills/book-atlas/SKILL.md` (정리 세션 1단계)

- [ ] **Step 1: §9 의 분할 조건을 고친다 (SKILL-004)**

`toc-pipeline.md` 의 아래 블록을

```
- 그 항목의 원문 범위가 6책쪽을 넘는다
- 그 항목이 자체 하위 제목을 가진다
```

이렇게 바꾼다.

```
- 그 항목이 자체 하위 제목을 가진다
```

그리고 그 블록 바로 뒤에 문단을 넣는다.

> **쪽수는 자동 트리거가 아니라 점검 신호다.** 예전 규칙은 "6책쪽 초과"를 조건으로 뒀으나
> 근거 없는 상수였다. 실측 사례(*Designing LLM Applications*, 절 202개(길이가 1쪽 이상인 것 171개))에서 중앙값은 1쪽,
> 6쪽을 넘는 절은 둘뿐이었고 **그 둘 다 이미 자체 하위 제목을 가져** 쪽수 조건이 단독으로
> 작동한 적이 없다. 대신 이렇게 쓴다 — 그 책 절 길이 분포의 **상위 5%**를 넘는데 자체 하위
> 제목이 없으면, 쪼갤 자연 경계가 정말 없는지 본문을 확인하고 판단 근거를 `_coverage.md` 에
> 남긴다. 절대 상수 대신 책마다 계산하며, 자동으로 쪼개지 않는다.

- [ ] **Step 2: PDF 교체 감지 절차를 넣는다 (SKILL-005)**

`toc-pipeline.md` §4 끝에 넣는다.

> ### PDF 가 바뀌면 오프셋부터 다시 검산한다
>
> `_global/config.md` 의 `source_pdf` 가 가리키는 파일이 없거나 이름이 바뀌었으면 **정리를
> 이어가기 전에** ①`pdfinfo` 로 쪽 수를 확인하고 ②러닝 푸터에서 오프셋을 직접 도출한 뒤
> `verify-offset.sh` 로 서로 다른 책쪽 표본 5개 이상을 검산하고 ③`source-manifest.md` 의
> 쪽 오프셋 표와 목차 트리를 갱신한다(`config.md` 에 `page_offset` 을 두었다면 함께 맞춘다 —
> 선택 필드이고 정본은 `source-manifest.md` 다).
>
> **오프셋이 달라졌다면 기존 노트의 `pages:` 와 본문 쪽 인용은 전부 무효다.** 판본이 바뀌면
> 쪽 매김만이 아니라 텍스트 레이어 품질도 달라질 수 있다 — 옛 판본이 코드·표를 잘라
> 렌더했다면 "원문이 잘려 있다"는 노트의 고지도 함께 무효가 된다.

`SKILL.md` 정리 세션 1단계 "위치 확인" 에 한 줄 덧붙인다.

> `source_pdf` 파일이 실제로 존재하는지 확인한다. 없거나 이름이 다르면 `toc-pipeline.md` §4 의
> **PDF 교체 절차**를 먼저 밟는다.

- [ ] **Step 3: 스펙과 어긋나지 않는지 확인한다**

Run: `grep -n '6책쪽' {skill}/skills/book-atlas/ -r`
Expected: 출력 없음 (설계 명세 `docs/specs/2026-08-31-book-atlas-design.md` §7 에도 같은 문구가
있으면 함께 고치고, 그 파일 `## 변경 이력` 에 한 줄 남긴다)

- [ ] **Step 4: 설치본에 반영한다**

```bash
cd {skill} && ./install.sh
grep -c '점검 신호' ~/.claude/skills/book-atlas/references/toc-pipeline.md
```
Expected: `1` 이상

- [ ] **Step 5: 커밋**

```bash
cd {skill}
git add skills/ docs/
git commit -m "docs(book-atlas): 분할의 쪽수 조건을 점검 신호로 강등 + PDF 교체 절차 (SKILL-004·005)"
```

---

### Task 8: 원장 뼈대 생성과 2~7장 재검수 착수 (0단계)

**Files:**
- Create: `{vault}/_global/fixes/ch01.md` … `ch07.md`
- Create: `{vault}/_global/fixes/cross-chapter.md`
- Create: `{vault}/_global/fixes/skill.md`

**Interfaces:**
- Consumes: Task 1 의 `lint-ledger.py`
- Produces: 채워진 장별 원장 — 두 번째 계획(교정 실행)의 입력

- [ ] **Step 1: 빈 원장 9개를 만든다**

각 파일은 제목 한 줄만 둔다. 예: `ch02.md` 는 `# 2장 원장` 한 줄.

`skill.md` 에는 **여섯 행**(SKILL-001 · 001b · 002 · 003 · 004 · 005)을 미리 채운다.
이 계획 Task 3~7 이 그 행들을 닫는다. 첫 행의 모습:

```markdown
### SKILL-001 · K · skills/book-atlas/scripts/check-chapter.sh
- **무엇** 노트 간 선언 구간에 구멍이 있어도 게이트가 통과시킨다
- **근거** 감사에서 9곳이 이 구멍으로 샜다. 예: 3장 Postprocessing 절(책 p.82)이
  `03e-wordpiece` 의 선언 구간 안인데 어느 노트에도 없다
- **조치** `_coverage.md` 표 1 의 책쪽 구간을 정규화해 챕터 범위를 빈틈없이 덮는지 검사하고,
  구멍이 있으면 `bad` 로 실패시킨다. 계획 Task 3 참조.
- **검증** `grep -q "선언 구간이 챕터를 덮음" skills/book-atlas/scripts/check-chapter.sh`
- **상태** 열림
```

나머지 다섯 행도 같은 형식으로, `조치` 에 해당 Task 번호를, `검증` 에 그 변경이 들어갔는지
확인하는 grep 을 넣는다.

- [ ] **Step 2: 1장 원장을 채운다**

1장 재검수는 이미 끝났다. 발견 33건(오류 4 · 보완필요 13 · 사소 15 · 보류 1)과 축1 쪽
재기준화 19편이 **`{fixes}/_source-reaudit-ch01.md` 에 볼트 안으로 보존돼 있다**(세션 스크래치패드는
사라지므로 미리 옮겨 뒀다). 이를 명세 §3.3 형식으로 `ch01.md` 에 옮긴다. **근거 필드에 원문 인용을 반드시 넣는다** — 인용이 없는 항목은 새 PDF 에서
해당 쪽을 다시 뽑아 채운다.

- [ ] **Step 3: 1장 원장에 형식 검사를 돌린다**

Run: `python3 {vault}/_global/fixes/lint-ledger.py {vault}/_global/fixes/ch01.md`
Expected: `lint-ledger: PASS`

- [ ] **Step 4: 재검수 규약에 원장 작성 규칙을 추가한다**

`{scratchpad}/reaudit-protocol.md` 에 절을 하나 더한다.

> ## 산출물 — 원장에 직접 쓴다
>
> 산문 보고 대신 `{vault}/_global/fixes/chNN.md` 에 행을 직접 쓴다. **이 파일 하나만 쓸 수 있고
> 볼트 노트는 여전히 수정 금지다.** 행 형식은 아래 고정이며, 다 쓴 뒤
> `python3 {vault}/_global/fixes/lint-ledger.py <그 파일>` 을 돌려 PASS 를 확인하고 보고한다.
>
> (명세 §3.3 의 행 형식 예시를 그대로 붙여 넣는다)
>
> ID 는 `CH{장번호 두 자리}-{001부터}`. 단계 태그는 축에 따라 `S`(구조) `P`(쪽) `E`(오류)
> `G`(보완필요) `M`(사소). 쪽 재기준화는 노트당 한 행씩 `P` 로 만든다.

- [ ] **Step 5: 2~7장 재검수를 띄운다**

장마다 담당 노트를 12편 안팎으로 나눠 에이전트를 보낸다(1장은 12+7 로 둘이었다).
각 브리프에 반드시 넣는다 — ①규약 파일 경로 ②담당 노트 목록 ③그 장의 **실제 책쪽 구간**
(2장 33–68 · 3장 69–86 · 4장 87–116 · 5장 119–148 · 6장 149–172 · 7장 173–190) ④새 판본
목차의 그 장 절 시작쪽 ⑤이전 감사가 그 노트들에 남긴 지적(축 3 재판정용).

- [ ] **Step 6: 도착한 원장에 형식 검사를 돌린다**

Run: `python3 {vault}/_global/fixes/lint-ledger.py {vault}/_global/fixes/`
Expected: `lint-ledger: PASS`. 실패하면 해당 에이전트에게 오류 목록을 그대로 보내 고치게 한다.

- [ ] **Step 7: 커밋**

```bash
cd {vault}
git add _global/fixes/
git commit -m "docs(fixes): 1~7장 원장 — 재검수 산출물"
```

---

## 다음 계획

Task 8 이 끝나면 원장에 전체 항목이 모인다. 그것을 입력으로 **교정 실행 계획**을 쓴다 —
S(구조) → P(쪽) → E·G(내용) → M(사소) 순서로, 각 단계 끝에 `reconcile.py` 로 닫는다.
그 계획은 원장이 채워지기 전에는 쓸 수 없다.
