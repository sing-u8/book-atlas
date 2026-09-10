# CLAUDE.md

이 저장소(book-atlas 스킬 자체)를 고칠 때 읽는다. 스킬을 **쓰는** 규칙은
`skills/book-atlas/SKILL.md` 에 있고, 이 문서는 스킬을 **만드는** 쪽이다.

## 고쳤으면 반드시 다시 설치한다

```bash
./install.sh --all
```

**이 저장소를 고치는 것만으로는 아무것도 바뀌지 않는다.** 실제로 실행되는 것은
설치본이고, 두 군데에 있다.

| 호스트 | 설치 경로 |
|---|---|
| Claude Code | `~/.claude/skills/book-atlas/` |
| Codex | `${CODEX_HOME:-$HOME/.codex}/skills/book-atlas/` |

`--claude` 나 `--codex` 로 한쪽만 설치하면 **다른 쪽은 옛 버전으로 남는다.**
실제로 그렇게 됐던 적이 있다 — 한 세션에서 스크립트 세 건을 고치고 Claude 쪽만
`cp` 로 옮긴 결과, Codex 설치본이 나흘 전 버전에 머물러 이미 고친 조용한 실패를
그대로 겪고 있었다. 파일 하나씩 복사하지 말고 **항상 `--all`** 을 쓴다.

설치가 끝나면 저장소는 그대로다(`install.sh` 는 저장소 밖으로 rsync 만 한다).
설치 자체는 커밋할 것이 없다.

## 커밋 전에 돌린다

```bash
bash skills/book-atlas/scripts/tests/run-tests.sh
```

전부 통과해야 한다. 스크립트를 고쳤으면 **회귀 검사를 먼저 쓴다** — 이 저장소의
검사 스크립트들은 조용히 실패한 이력이 있어서(아래), 실패를 재현하는 테스트 없이
고치면 고쳤는지 알 수 없다.

## 조용한 실패를 경계한다

이 저장소가 고쳐 온 결함의 대부분은 **오류를 내지 않으면서 검사를 건너뛰는** 종류다.

- `pdftotext -f 191 -l 10` 은 뒤집힌 범위에 오류 없이 빈 출력을 낸다 → 후보 0건 →
  `누락 의심 0건` + exit 0. 검사를 안 한 것과 통과가 구별되지 않는다.
- 후보를 걸러내는 필터는 **몇 건을 걸렀는지 항상 인쇄한다.** 조용히 줄이면 진짜
  발견이 사라져도 모른다.

새 검사를 넣을 때는 "이 검사가 아무것도 안 읽었을 때 무엇이 보이는가"를 먼저 답한다.

## 발견은 볼트 원장에 적는다

스킬 결함은 이 저장소가 아니라 **사용 중인 볼트**의 `_global/fixes/skill.md` 에
`SKILL-NNN` 행으로 남긴다. 행 형식은 `무엇 / 근거 / 조치 / 검증 / 상태` 다섯 필드
고정이고 `lint-ledger.py` 가 실제로 파싱하므로 한 글자도 벗어나면 안 된다.

```bash
python3 <vault>/_global/fixes/lint-ledger.py <vault>/_global/fixes/skill.md
```

## 스크립트 규약

- **종료코드** — `0` 통과 · `2` 검사 실패(사유는 stderr) · `1` 사용법·입력 오류.
  `audit-delivery.py` 만 예외로 경고 전용이라 사용법 오류가 아니면 항상 `0`.
- **bash 3.2 호환** — macOS 기본 bash 가 3.2 다. 배열·`mapfile`·연관배열을 쓰지
  않는다.
- **셔뱅이 있으면 실행 권한도 준다.** 셔뱅은 직접 실행해도 된다는 선언이라,
  권한이 없으면 그 선언이 거짓이 된다.

## 저장소 배치

```
skills/book-atlas/     설치되는 것 — 이것만 rsync 대상이다
  SKILL.md             스킬 본체(사용 규칙)
  references/          SKILL.md 가 필요할 때 읽는 문서 5종
  scripts/             검사·빌드 스크립트 + tests/
  assets/              graph.html 과 뷰어 라이브러리
docs/                  설계 스펙·구현 계획 — 설치본에 딸려가지 않는다
install.sh             --claude | --codex | --all (기본 --claude)
```

`docs/` 에 README 용 이미지도 둔다. `skills/book-atlas/assets/` 에 두면 설치본이
불필요하게 커진다.
