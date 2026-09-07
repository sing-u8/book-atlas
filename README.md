# book-atlas — 원서 한 권을 목차 구조 그대로

원서 PDF 한 권을 목차 구조 그대로 충실하게 정리하고, 책→챕터→절→개념의 연결을 three.js 기반 3D 그래프로 시각화하는 정리 중심 학습 스킬입니다. 목차를 추출·검산하여 저장소를 부트스트랩하고, 절 단위 노트(작성 규칙 12개)와 책 전체 용어집을 관리하며, 세션마다 그래프를 자동 재생성합니다.

인출 훈련(퀴즈·꼬리질문·암기)은 이 스킬의 몫이 아닙니다 — 그 요청은 [`deep-tutor`](https://github.com/RoundTable02/tutor-skills)로 안내합니다.

## 설치 및 제거

```bash
# Codex에 설치
./install.sh --codex

# Claude Code에 설치(기존 기본 동작)
./install.sh --claude

# 두 호스트에 모두 설치
./install.sh --all
```

Codex 설치본은 `${CODEX_HOME:-$HOME/.codex}/skills/book-atlas/`, Claude Code 설치본은
`~/.claude/skills/book-atlas/`에 놓입니다. Codex에서는 설치 다음 턴부터 자동으로
발견되며, 명시적으로 호출하려면 `$book-atlas`를 사용합니다. 제거할 때도 같은 대상을
`./uninstall.sh --codex|--claude|--all`로 지정합니다.

## 사용 흐름

### 1. 온보딩 (저장소 부트스트랩)
- PDF 스캔본 검사
- 목차 자동 추출 및 계층 판정
- 쪽 오프셋 검산 (표본 3개)
- `_global/config.md` (언어·vault명) 및 `source-manifest.md` (목차·오프셋) 작성
- 챕터 디렉터리·용어집·그래프 뼈대 생성

### 2. 정리 세션 (기본 루프)
1. 진행 위치 확인
2. 새 챕터: `_coverage.md` 작성 → 분할·병합 규칙 적용
3. 절 노트 작성 (작성 규칙 12개 준수)
4. 용어집 등재 → `check-note.sh` 게이트
5. 챕터 완결: `_chapter.md` 완성 → `check-chapter.sh` 게이트
6. 그래프 재생성 (`build-graph.py`) → 경고 처리 → `graph/graph.html` 새로고침

### 3. 그래프 보기
<!-- 그래프 스크린샷 자리 -->

타입별 노드 색상 (책/챕터/절/개념), 레이어 토글, 호버 하이라이트, Obsidian 클릭 지원.

## 저장소 구조 (`{book-slug}-atlas/`)

```
├── _global/
│   ├── config.md              # 언어, vault명, 진행 위치
│   └── source-manifest.md     # 목차 트리, 쪽 오프셋 (정본)
├── _glossary.md               # 책 전체 단일 용어집
├── _assets/                   # 추출 도표
├── graph/
│   ├── graph.html             # 뷰어 (불변)
│   ├── graph-data.js          # 빌드 산출물 (손 편집 금지)
│   └── lib/3d-force-graph.min.js
├── chapter-01-{slug}/
│   ├── _chapter.md            # 챕터 개요
│   ├── _coverage.md           # 원문 커버리지 대응표
│   └── 01-{slug}.md           # 절 노트 (H2 6개·도표·연결)
└── chapter-NN-{slug}/
```

절 노트 필수 섹션: 한눈에 보기 · 왜 이 절인가 · 본문 정리 · 개념 · 연결 · 스스로 확인.

## deep-tutor 와의 역할 분담

- **book-atlas** — 정리와 시각화. 목차 구조 충실성·노트 작성 규칙·그래프 대시보드.
- **deep-tutor** — 인출 훈련. 반복 퀴즈·꼬리질문 사슬·약점 추적.

## 참고 문서

- [설계 스펙](docs/specs/2026-08-31-book-atlas-design.md) — 전체 구조·스키마·게이트·이식 지도
- [구현 계획](docs/plans/) — 작업 분해·일정·마일스톤
