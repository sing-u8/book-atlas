# 개념 그래프 — 데이터 계약 · 빌드 · 뷰어

> 저장소가 정본이고 그래프는 그 **산출물**이다. `build-graph.py` 가 노트·용어집·목차 트리를 읽어
> `graph/graph-data.js` 를 통째로 다시 쓰고, `graph/graph.html` 이 그것을 그린다. 이 문서는 그
> 데이터 계약, 빌더 사용법과 경고 4종, 뷰어 조작법, 그리고 Obsidian 클릭이 안 될 때의 진단을 담는다.

**언제 읽는가**

- 온보딩에서 `graph/` 를 설치하고 첫 빌드를 돌릴 때 (`toc-pipeline.md` §8)
- 정리 세션 종료 리추얼 — 빌드하고 경고를 처리할 때
- 사용자가 그래프를 열거나 갱신해 달라고 할 때, 클릭이 안 된다고 할 때

---

## 1. 데이터 계약 — `graph/graph-data.js`

빌더가 저장소를 스캔해 생성한다. JSON 이 아니라 `.js` 인 이유: `file://` 로 연 HTML 은 로컬 JSON
`fetch` 가 CORS 에 막히지만 `<script src>` 는 통과한다. 그래서 뷰어는 서버 없이 파일을 더블클릭하는
것만으로 열린다.

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
      def: "정의 첫 문장" }
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

### 노드 4종

| type | id | label | 그 외 필드 |
|---|---|---|---|
| `book` | `book:{book_slug}` | `book_title` | — (경로 없음) |
| `chapter` | `chapter:{챕터 디렉터리명}` | `{번호}. {제목}` (목차 트리 행에서) | `path` = `{챕터}/_chapter.md`, `progress: {done, total}` |
| `note` | `note:{vault 기준 경로, 확장자 없음}` | `{section} {title}` (frontmatter) | `path` = `{vault 기준 경로}.md`, `status` = `draft`\|`done` |
| `concept` | `concept:{슬러그}` | 슬러그 | `def` = 용어집 정의의 **첫 줄**(120자에서 자름) |

- **노드 `size` 는 빌더가 넣지 않는다** — 뷰어가 차수(degree)로 계산한다.
- **챕터 노드는 노트가 한 장도 없어도 목차 트리에서 전부 생성된다.** 그래서 온보딩 직후부터 그래프가
  목차 뼈대를 보여주고, 정리가 진행될수록 노트·개념이 그 위에 자라난다. 노트가 아직 없는 챕터의
  `progress` 는 `done: 0`, `total` = 그 챕터의 목차 최하위 항목 수(subsection 이 있으면 subsection
  개수, 없으면 section 개수)다. 노트가 하나라도 생기면 그때부터 `total` 은 **실제 노트 개수**로,
  `done` 은 `status: done` 인 노트 개수로 바뀐다.

### 링크 5종

| type | 방향 | 원천 |
|---|---|---|
| `toc` | book→chapter, chapter→note | 목차 트리 표 + 각 챕터 디렉터리에서 실제로 수집된 노트 |
| `covers` | note→concept | 노트 frontmatter `concepts:` 배열 (굵은 엣지) |
| `mentions` | note→concept | 노트 본문의 `[[슬러그]]` 링크 (얇은 엣지) |
| `related` | concept↔concept (무방향) | 용어집 `- 섞이는 말: [[슬러그]]` |
| `note-link` | note↔note (무방향) | 노트 `## 연결` 안의 노트 링크 |

- 같은 `(source, target, type)` 엣지는 중복 제거된다.
- **`covers` 가 있으면 같은 쌍의 `mentions` 는 내보내지 않는다** — 중요하게 다룬 개념이 본문에도
  당연히 링크돼 있으므로, 두 엣지가 겹쳐 그려지는 것을 막는다.
- 무방향 엣지(`related`·`note-link`)는 두 id 를 정렬해 한 방향으로만 저장한다.

### 무엇이 무엇을 만드는가

| 원천 | 만드는 것 |
|---|---|
| `_global/config.md` | `book.vault`(= `vault_name`), book 메타 폴백. **이 파일이 없으면 빌드 자체가 exit 1** |
| `_global/source-manifest.md` 의 `## 목차 트리` 표 | book·chapter 노드, `toc`(book→chapter) |
| 절 노트 frontmatter | note 노드(label·status), `covers` |
| 절 노트 본문 — 구분자 **위**, 코드펜스 제거 후 | `mentions` |
| 절 노트 `## 연결` 절 | `note-link` |
| `_glossary.md` | concept 노드(`def`), `related` |

읽는 규칙 셋을 알아 두면 결과가 예측된다.

1. **노트로 수집되는 파일**은 `chapter-*` 디렉터리 **바로 아래**에 있고 파일명이 숫자로 시작하는
   `.md` 뿐이다(`**/chapter-*/[0-9]*.md`). `_chapter.md`·`_coverage.md` 는 노트가 아니다.
2. **구분자 아래(사용자 메모)는 스캔하지 않는다.** 메모에 적은 위키링크는 그래프에 나타나지 않는다.
3. **`[[X]]` 가 개념인지 노트인지는 파일 존재로 갈린다** — vault 안(`graph/` 제외) 어딘가에 `X.md` 가
   있으면 노트 링크, 없으면 개념 참조다. `[[_glossary#슬러그]]` 는 개념 슬러그로 되돌려 대조하고,
   그 외 `[[_...]]`(`[[_chapter]]`·`![[_assets/...]]`)는 건너뛴다. `check-note.sh` 와 같은 규칙이다.

---

## 2. 빌드 — `build-graph.py`

```bash
python3 "<book-atlas-root>/scripts/build-graph.py" "{book-slug}-atlas"
```

- 인자는 vault 루트 경로. **생략하면 CWD** 를 vault 루트로 본다.
- python3 **표준 라이브러리만** 쓴다 — 설치할 것이 없다.
- 산출물은 `{vault}/graph/graph-data.js` 하나. `graph/` 가 없으면 만든다. `graph.html` 과
  `lib/` 는 건드리지 않는다(온보딩 때 한 번 복사하고 그 뒤 불변).
- **성공하면 stdout 이 조용하다.** 아무것도 안 찍히면 성공이다 — 경고만 stderr 에 `경고: ` 접두로 나온다.

| exit | 의미 |
|---:|---|
| 0 | 생성 완료 — **경고가 있어도 0이다** |
| 1 | vault 루트가 아님(`_global/config.md` 없음) 또는 출력 불가 |

빌더는 **게이트가 아니라 리포터**다. 통과·실패를 판정하는 것은 `check-note.sh`·`check-chapter.sh` 이고,
빌더는 저장소를 훑다 눈에 띈 어긋남을 알려줄 뿐 그것 때문에 실패하지 않는다.

**언제 돌리는가**: 온보딩 마지막(목차 뼈대 그래프를 여는 시점)과 **정리 세션을 끝낼 때마다**.
세션을 빌드 없이 끝내지 않는다 — 그래프가 저장소보다 낡은 채로 남는다. 빌드 뒤에는 경고를 읽어
처리하고, 사용자에게 "`graph.html` 을 새로고침하세요"라고 안내한다.

### 경고 4종 — 무슨 뜻이고 무엇을 하는가

| # | stderr 문구 | 뜻 | 대응 |
|---|---|---|---|
| ① | `경고: note:… 의 [[X]] 은(는) 용어집에 없는 개념 참조`<br>`경고: note:… frontmatter concepts 의 [[X]] 이(가) 용어집에 없는 개념 참조` | 노트가 링크한 `X` 가 용어집에도 없고, `X.md` 파일도 없다 | 용어라면 `_glossary.md` 에 등재한다. **노트 링크 오타일 수도 있다** — `[[02-rankng]]` 처럼 없는 파일을 가리키면 개념으로 분류돼 여기로 떨어진다. 오타부터 의심한다 |
| ② | `경고: {챕터}/_coverage.md → [[X]] 은(는) 존재하지 않는 노트로 가는 링크` | 커버리지가 가리키는 `X.md` 가 그 챕터 디렉터리에 없다 | 아직 안 쓴 노트면 정상 — 그 행이 곧 할 일이다. 파일명 오타면 고친다. **챕터를 완결하기 전에는 반드시 해소해야 한다** — `check-chapter.sh` 가 같은 것을 실패로 잡는다 |
| ③ | `경고: {노트 경로} 은(는) {챕터}/_coverage.md 에 없음` | 고아 노트 — 노트는 있는데 커버리지 어디에도 안 적혔다 | 커버리지 표 1의 해당 행 `정리 노트` 칸에 `[[슬러그]]` 를 넣는다. 분할된 자식 노트를 빠뜨렸을 때 가장 흔하다(`toc-pipeline.md` §9) |
| ④ | `경고: 용어집 항목 {슬러그} 을(를) 참조하는 노트가 없음` | 어느 노트도 그 용어를 링크하지 않는다 | 정리가 진행 중이면 정상(먼저 등재한 용어). 챕터를 다 쓴 뒤에도 남으면 등재가 이르거나 불필요한 것이니, 해당 절 노트에서 링크하거나 항목을 지운다 |

세 가지 미세한 점.

- **①은 `check-note.sh` 의 용어 대조와 글자 그대로 같은 규칙이다.** 그러니 ①이 뜨는 노트는
  게이트도 통과할 수 없다 — 아직 게이트를 안 돌린 노트라는 뜻이다. 손으로 고치기 전에
  `check-note.sh` 를 돌려 정확한 실패 목록부터 받는다.
- **②는 커버리지 파일 전체의 위키링크를 본다** — 상태 칸 사유에 적은 링크(`부분 — 세부 예제는
  [[04-later]] 에서`)까지 포함한다. `check-chapter.sh` 는 `정리 노트` 칸만 보므로, 게이트는
  통과하는데 빌더만 경고하는 조합이 정상적으로 나올 수 있다.
- **④는 용어집 안에서 서로 거는 링크(`섞이는 말`)를 참조로 치지 않는다.** 노트가 링크해야 참조다.

### 그래프가 비어 보일 때

| 증상 | 확인할 것 |
|---|---|
| 챕터 노드가 하나도 없다 | `source-manifest.md` 에 `## 목차 트리` 헤딩이 정확히 그 문자열인지, 표의 왼쪽 네 열이 `계층·번호·제목·슬러그` 순서인지 |
| 노트를 썼는데 노드가 안 생긴다 | 파일이 `chapter-*` 디렉터리 **바로 아래**에 있고 파일명이 숫자로 시작하는지, frontmatter 가 첫 줄 `---` 로 시작하는지 |
| 노트 노드는 있는데 챕터에 안 붙어 떠 있다 | 목차 트리 표의 `chapter` 행 **슬러그 칸**이 실제 챕터 디렉터리명과 글자 그대로 같은지. 다르면 챕터 노드는 생기지만 노트가 그 아래로 안 붙는다. 그 챕터의 `chapter` 행이 아예 없어도 같은 증상이다(상태값이 `미파싱`인 것 자체는 무관 — 빌더는 상태 칸을 보지 않는다) |
| 개념이 하나도 없다 | vault 루트에 `_glossary.md` 가 있는지, 항목 제목이 `## 슬러그` 형식인지 |
| `exit 1` | 인자로 준 경로가 vault 루트(= `_global/config.md` 가 있는 디렉터리)가 맞는지 |

---

## 3. 뷰어 — `graph/graph.html`

```bash
open "{book-slug}-atlas/graph/graph.html"     # macOS. 브라우저로 파일을 열기만 하면 된다
```

서버도, 인터넷도 필요 없다 — 3d-force-graph 번들이 `graph/lib/` 에 동봉돼 있다. **`graph.html` 은
불변이다**: 데이터만 다시 만들고 브라우저를 새로고침하는 것이 곧 갱신이다.

### 화면 구성

왼쪽 위 패널 하나, 오른쪽 위 정보 패널 하나. UI 라벨은 한국어다.

| 자리 | 항목 | 하는 일 |
|---|---|---|
| 패널 맨 위 | `노드 검색…` 입력창 | 라벨 부분일치로 **첫 매치**를 하이라이트하고 카메라를 그 노드로 옮긴다 |
| **레이어** | `목차 (책·챕터·절)` / `개념` | 노드 층을 통째로 켜고 끈다. 끈 층에 걸린 엣지도 함께 사라진다 |
| **엣지** | `목차 계층`(toc) · `핵심 개념`(covers) · `언급`(mentions) · `개념 관계`(related) · `노트 연결`(note-link) | 엣지 타입별 표시 토글 |
| **범례** | 책 · 챕터 · 노트 · 개념 | 타입별 색 |

### 그림 규칙

| 규칙 | 내용 |
|---|---|
| 색 | 책 노랑 · 챕터 주황 · 노트 청록 · 개념 보라 |
| 크기 | 차수(degree)에 비례 — 연결이 많은 노드가 크다 |
| 반투명 | `status: draft` 인 노트는 반투명 청록. **진행 대시보드를 겸한다** — 아직 반투명한 노트가 남은 일이다 |
| 엣지 굵기 | `covers` 만 두 배 굵다 |

### 조작

- **호버** — 그 노드와 이웃만 색이 남고 나머지는 회색으로 죽는다. 절 하나가 어떤 개념들을 물고 있는지 볼 때.
- **검색** — 입력할 때마다 첫 매치를 하이라이트하고 카메라를 옮긴다. 필터가 아니라 하이라이트다(다른 노드는 사라지지 않고 회색으로 남는다). 매치가 없으면 하이라이트가 해제된다.
- **드래그·휠** — 회전·확대(3d-force-graph 기본 조작).
- **클릭** — 아래 표대로 갈린다.

| 노드 | `vault_name` 이 있을 때 | 비어 있을 때 |
|---|---|---|
| 챕터·노트(경로 있음) | `obsidian://open?vault=…&file=…` 로 Obsidian 에서 그 파일을 연다 | 정보 패널 |
| 개념 | Obsidian 에서 `_glossary` 를 연다 | 정보 패널(정의 표시) |
| 책 | 정보 패널 (책 노드에는 경로가 없다) | 정보 패널 |

정보 패널에 뜨는 것: 개념은 `def`(용어집 정의의 첫 줄. 비어 있으면 `(정의 없음)`), 노트는
`상태`·`경로`, 챕터는 `진행: done / total`, 책은 이름과 타입뿐.

---

## 4. Obsidian 클릭이 안 될 때

증상은 대개 하나다 — 노드를 클릭했는데 아무 일도 안 일어나거나, 정보 패널만 열린다. 위에서부터 확인한다.

1. **정보 패널만 열린다 = `vault` 가 비어 있다.** 이건 고장이 아니라 설계된 폴백이다.
   `_global/config.md` 의 `- vault_name:` 을 채우고 **빌드를 다시 돌린다.** vault 이름은
   `graph-data.js` 의 `book.vault` 에 구워져 나가므로, config 만 고치고 재빌드하지 않으면 그대로다.
2. **vault 이름이 정확한가.** Obsidian 이 아는 vault 이름과 **글자 하나까지** 같아야 한다(공백·대소문자
   포함). Obsidian 좌하단의 vault 전환 메뉴에 뜨는 이름이 그것이다. 브라우저 주소창에
   `obsidian://open?vault=<이름>` 을 직접 쳐서 Obsidian 이 열리는지로 단독 검증할 수 있다.
   이 값은 온보딩 때 사용자에게 **직접 묻는다** — 추정하면 모든 클릭이 조용히 실패한다.
3. **vault 를 어느 폴더로 열었는가.** `file=` 에 들어가는 경로는 **vault 루트 기준 상대경로**이고,
   빌더는 그 경로를 `{book-slug}-atlas/` 기준으로 만든다. 그러니 Obsidian vault 는
   **`{book-slug}-atlas/` 자체**여야 한다. 프로젝트 루트를 vault 로 열었다면 경로 앞에
   `{book-slug}-atlas/` 가 빠져 파일을 못 찾는다 — vault 를 다시 여는 쪽이 맞다.
4. **URI 인코딩은 뷰어가 이미 한다.** vault 이름과 파일 경로 모두 `encodeURIComponent` 를 거치므로
   공백·한글·`&` 가 들어 있어도 그대로 동작한다. 링크에서 `.md` 확장자는 떼고 보낸다(Obsidian 규칙).
   그래서 주소창에 손으로 URI 를 만들어 넣을 때는 **확장자를 빼고 공백을 `%20` 으로** 바꿔야 한다.
5. **브라우저가 막고 있을 수 있다.** `obsidian://` 은 외부 앱 프로토콜이라 브라우저가 "이 사이트가
   Obsidian 을 열려고 합니다" 확인을 띄운다 — 허용해야 열린다. Obsidian 이 실행돼 있지 않으면
   먼저 실행한 뒤 다시 클릭한다.
6. **Obsidian 이 "새 파일을 만들까요"를 묻는다** = 그 경로에 파일이 없다는 뜻이다. 만들지 말고
   빌드를 다시 돌린다 — 노트를 옮기거나 이름을 바꾼 뒤 재빌드를 안 한 상태다.

---

## 5. `graph-data.js` 는 손으로 편집하지 않는다

**절대 규칙이다.** 노트·용어집·목차 트리가 정본이고 `graph-data.js` 는 그것을 옮겨 적은 사본일 뿐이다.
손으로 고치면 두 가지가 동시에 일어난다 — 다음 빌드에서 그 수정이 통째로 사라지고, 그 사이 그래프는
저장소와 다른 이야기를 한다. 그래프에서 무언가를 바꾸고 싶으면 **원천을 바꾸고 다시 빌드한다.**

| 바꾸고 싶은 것 | 고칠 원천 |
|---|---|
| 노드 라벨·진행률 | 노트 frontmatter(`section`·`title`·`status`), 목차 트리 표 |
| 굵은 개념 엣지 | 노트 frontmatter `concepts:` |
| 얇은 언급 엣지 | 본문의 `[[슬러그]]` 링크 |
| 개념 노드·정의 | `_glossary.md` 항목과 그 첫 문장 |
| 개념끼리의 연결 | `_glossary.md` 의 `- 섞이는 말:` |
| 노트끼리의 연결 | 노트 `## 연결` 항목 |
| vault 이름 | `_global/config.md` 의 `vault_name` (고친 뒤 재빌드) |

같은 이유로 `graph.html` 과 `graph/lib/` 도 vault 안에서 편집하지 않는다. 뷰어를 고쳐야 한다면
스킬 쪽 `<book-atlas-root>/assets/graph.html` 을 고치고 vault 로 다시 복사한다.
