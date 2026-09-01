#!/usr/bin/env python3
"""book-atlas 그래프 빌더 — vault 를 스캔해 graph/graph-data.js 를 재생성한다."""
import sys, re, json, datetime
from pathlib import Path

# 노트 본문 중 이 구분자 아래는 사용자 영역 — 스캔 대상에서 제외한다.
# check-note.sh 의 SEP 상수와 바이트 단위로 동일해야 한다.
SEP = '<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->'

KV_RE = re.compile(r'^-\s+([A-Za-z0-9_]+):\s*(.*)$', re.MULTILINE)
WIKILINK_RE = re.compile(r'\[\[([^\]]+)\]\]')
GLOSSARY_HEAD_RE = re.compile(r'^##\s+(\S+)(?:\s+\((.+)\))?\s*$')
RELATED_RE = re.compile(r'섞이는\s*말:\s*\[\[([^\]]+)\]\]')
FM_LINE_RE = re.compile(r'^([A-Za-z0-9_]+):\s*(.*)$')


def parse_kv(path):
    """`- key: value` 줄들을 dict 로 (config·manifest 소스 절 공용)."""
    text = Path(path).read_text(encoding='utf-8')
    kv = {}
    for m in KV_RE.finditer(text):
        kv[m.group(1)] = m.group(2).strip()
    return kv


def parse_manifest(path):
    """목차 트리 표를 행 단위 파싱해 챕터 목록을 만든다.

    반환: [{dir, label, lowest}, ...] — dir=슬러그, label="{번호}. {제목}",
    lowest = subsection 행이 하나라도 있으면 subsection 개수, 아니면 section 개수.
    """
    text = Path(path).read_text(encoding='utf-8')
    lines = text.splitlines()

    start = None
    for i, line in enumerate(lines):
        if line.strip() == '## 목차 트리':
            start = i + 1
            break
    if start is None:
        return []

    rows = []
    for line in lines[start:]:
        s = line.strip()
        if not s:
            if rows:
                break
            continue
        if s.startswith('|'):
            rows.append(s)
        elif rows:
            break

    data_rows = rows[2:]  # 헤더 행 + 구분 행(|---|) 제외
    chapters = []
    cur = None
    for r in data_rows:
        cells = [c.strip() for c in r.strip().strip('|').split('|')]
        if len(cells) < 4:
            continue
        level, num, title, slug = cells[0], cells[1], cells[2], cells[3]
        if level == 'chapter':
            cur = {'dir': slug, 'label': f'{num}. {title}', 'sec': 0, 'subsec': 0}
            chapters.append(cur)
        elif level == 'section' and cur is not None:
            cur['sec'] += 1
        elif level == 'subsection' and cur is not None:
            cur['subsec'] += 1

    for c in chapters:
        c['lowest'] = c['subsec'] if c['subsec'] > 0 else c['sec']
        del c['sec']
        del c['subsec']
    return chapters


def strip_fences(text):
    """```로 시작하는 줄을 토글 삼아 코드펜스 안쪽(과 마커 줄 자체)을 제거한다.

    check-note.sh 의 `awk '/^```/{f=!f;next} !f'` 와 동일 의미.
    """
    out = []
    fenced = False
    for line in text.splitlines():
        if line.startswith('```'):
            fenced = not fenced
            continue
        if not fenced:
            out.append(line)
    return '\n'.join(out)


def _resolve_target(inner):
    """`[[...]]` 안쪽 raw 문자열 하나를 대조용 슬러그로 정규화한다.

    resolve_term()(check-note.sh) 과 동일 규칙: 별칭은 앞부분만,
    `_glossary#s` 는 개념 s, 그 외 `_` 접두는 skip(None), `#앵커`는 제거.
    """
    target = inner.split('|', 1)[0]
    if target.startswith('_glossary#'):
        return target[len('_glossary#'):]
    if target.startswith('_'):
        return None
    if '#' in target:
        return target.split('#', 1)[0]
    return target


def wiki_links(text):
    """펜스를 제거한 뒤 위키링크를 뽑아 정규화한 슬러그 목록을 돌려준다."""
    stripped = strip_fences(text)
    out = []
    for m in WIKILINK_RE.finditer(stripped):
        target = _resolve_target(m.group(1))
        if target:
            out.append(target)
    return out


def extract_section(text, heading):
    """`## {heading}` 로 시작하는 줄부터 다음 `## ` 줄 전까지를 뽑는다."""
    out = []
    capturing = False
    for line in text.splitlines():
        if not capturing and line.startswith(f'## {heading}'):
            capturing = True
            continue
        if capturing and line.startswith('## '):
            break
        if capturing:
            out.append(line)
    return '\n'.join(out)


def parse_frontmatter(text):
    """첫 `---` 쌍 안의 `key: value` 를 dict 로. concepts 는 인라인 리스트."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != '---':
        return {}
    fm = {}
    i = 1
    while i < len(lines) and lines[i].strip() != '---':
        m = FM_LINE_RE.match(lines[i])
        if m:
            key, val = m.group(1), m.group(2).strip()
            if key == 'concepts':
                lm = re.match(r'^\[(.*)\]$', val)
                items = []
                if lm:
                    for x in lm.group(1).split(','):
                        x = x.strip().strip('"').strip("'")
                        if x:
                            items.append(x)
                fm[key] = items
            else:
                fm[key] = val.strip('"').strip("'")
        i += 1
    return fm


def parse_glossary(path):
    """`## 슬러그 (원어)` 항목들을 {slug: {def, related}} 로."""
    text = Path(path).read_text(encoding='utf-8')
    lines = text.splitlines()
    n = len(lines)
    entries = {}
    i = 0
    while i < n:
        m = GLOSSARY_HEAD_RE.match(lines[i])
        if not m:
            i += 1
            continue
        slug = m.group(1)

        j = i + 1
        while j < n and lines[j].strip() == '':
            j += 1
        definition = ''
        if j < n and not lines[j].startswith('##'):
            definition = lines[j].strip()[:120]

        related = None
        k = j
        while k < n and not (lines[k].startswith('## ') and GLOSSARY_HEAD_RE.match(lines[k])):
            rm = RELATED_RE.search(lines[k])
            if rm:
                related = _resolve_target(rm.group(1))
            k += 1

        entries[slug] = {'def': definition, 'related': related}
        i = k
    return entries


def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()

    config_path = root / '_global' / 'config.md'
    if not config_path.is_file():
        print(f'build-graph: vault 루트가 아님 — {config_path} 없음', file=sys.stderr)
        return 1

    def warn(msg):
        print(f'경고: {msg}', file=sys.stderr)

    manifest_path = root / '_global' / 'source-manifest.md'
    glossary_path = root / '_glossary.md'

    config = parse_kv(config_path)
    manifest_kv = parse_kv(manifest_path) if manifest_path.is_file() else {}
    chapters = parse_manifest(manifest_path) if manifest_path.is_file() else []
    glossary = parse_glossary(glossary_path) if glossary_path.is_file() else {}
    glossary_slugs = set(glossary.keys())

    book_slug = manifest_kv.get('book_slug') or config.get('book_slug', '')
    book_title = manifest_kv.get('book_title') or config.get('book_title', '')
    vault_name = config.get('vault_name', '')

    # --- 1차 수집: 절 노트 원본(프런트매터·본문 구간)을 먼저 모아 note_index 를 만든다 ---
    note_paths = sorted(root.glob('**/chapter-*/[0-9]*.md'))
    raw_notes = []
    for p in note_paths:
        rel = p.relative_to(root)
        text = p.read_text(encoding='utf-8')
        fm = parse_frontmatter(text)
        sep_idx = text.find(SEP)
        above = text[:sep_idx] if sep_idx != -1 else text
        raw_notes.append({
            'relpath': str(rel.with_suffix('')).replace('\\', '/'),
            'path': str(rel).replace('\\', '/'),
            'chapter_dir': p.parent.name,
            'stem': p.stem,
            'fm': fm,
            'above': above,
            'conn_text': extract_section(above, '연결'),
        })

    # x.md 존재 검사 대상 = 수집된 절 노트 전체(그래프의 note 노드 전집과 동일)
    note_index = {}
    for n in raw_notes:
        note_index.setdefault(n['stem'], n['relpath'])

    nodes = []
    node_ids = set()
    links = []
    link_keys = set()

    def add_node(node):
        if node['id'] not in node_ids:
            node_ids.add(node['id'])
            nodes.append(node)

    def add_link(source, target, ltype):
        key = (source, target, ltype)
        if key not in link_keys:
            link_keys.add(key)
            links.append({'source': source, 'target': target, 'type': ltype})

    # --- book 노드 ---
    book_id = f'book:{book_slug}'
    add_node({'id': book_id, 'type': 'book', 'label': book_title})

    # --- chapter 노드 + toc(book→chapter, chapter→note) ---
    notes_by_chapter = {}
    for n in raw_notes:
        notes_by_chapter.setdefault(n['chapter_dir'], []).append(n)

    for ch in chapters:
        chapter_id = f"chapter:{ch['dir']}"
        chapter_notes = notes_by_chapter.get(ch['dir'], [])
        if chapter_notes:
            done = sum(1 for n in chapter_notes if n['fm'].get('status') == 'done')
            total = len(chapter_notes)
        else:
            done = 0
            total = ch['lowest']
        add_node({
            'id': chapter_id,
            'type': 'chapter',
            'label': ch['label'],
            'path': f"{ch['dir']}/_chapter.md",
            'progress': {'done': done, 'total': total},
        })
        add_link(book_id, chapter_id, 'toc')
        for n in chapter_notes:
            add_link(chapter_id, f"note:{n['relpath']}", 'toc')

    # --- concept 노드(용어집 전 항목) ---
    for slug, entry in glossary.items():
        add_node({'id': f'concept:{slug}', 'type': 'concept', 'label': slug, 'def': entry['def']})

    # --- note 노드 + covers/mentions/note-link 엣지 ---
    referenced_concepts = set()
    covers_pairs = set()

    for n in raw_notes:
        note_id = f"note:{n['relpath']}"
        title = n['fm'].get('title', '')
        section = n['fm'].get('section', '')
        label = f'{section} {title}'.strip()
        add_node({
            'id': note_id,
            'type': 'note',
            'label': label,
            'path': n['path'],
            'status': n['fm'].get('status', ''),
        })

        # covers: frontmatter concepts
        for c in n['fm'].get('concepts', []):
            referenced_concepts.add(c)
            if c not in glossary_slugs:
                warn(f"{note_id} frontmatter concepts 의 [[{c}]] 이(가) 용어집에 없는 개념 참조")
                continue
            concept_id = f'concept:{c}'
            add_link(note_id, concept_id, 'covers')
            covers_pairs.add((note_id, concept_id))

        # mentions: 본문(연결 포함) 의 개념 링크 — covers 와 같은 쌍이면 생략
        for name in dict.fromkeys(wiki_links(n['above'])):
            if name in note_index:
                continue  # 노트 링크 — note-link 쪽(연결 섹션 한정)에서 처리
            referenced_concepts.add(name)
            if name not in glossary_slugs:
                warn(f"{note_id} 의 [[{name}]] 은(는) 용어집에 없는 개념 참조")
                continue
            concept_id = f'concept:{name}'
            if (note_id, concept_id) in covers_pairs:
                continue
            add_link(note_id, concept_id, 'mentions')

        # note-link: `## 연결` 의 노트 링크만, 무방향
        for name in dict.fromkeys(wiki_links(n['conn_text'])):
            if name not in note_index:
                continue
            target_id = f'note:{note_index[name]}'
            a, b = sorted([note_id, target_id])
            add_link(a, b, 'note-link')

    # --- related: 용어집 "섞이는 말", 무방향 ---
    for slug, entry in glossary.items():
        rel = entry.get('related')
        if not rel or rel not in glossary_slugs:
            continue
        a, b = sorted([f'concept:{slug}', f'concept:{rel}'])
        add_link(a, b, 'related')

    # --- 경고 ②: _coverage.md 의 "정리 노트" 참조가 실제 노트 파일로 존재하는가 ---
    for ch in chapters:
        cov_path = root / ch['dir'] / '_coverage.md'
        if not cov_path.is_file():
            continue
        cov_text = cov_path.read_text(encoding='utf-8')
        for name in dict.fromkeys(wiki_links(cov_text)):
            if not (root / ch['dir'] / f'{name}.md').is_file():
                warn(f"{ch['dir']}/_coverage.md → [[{name}]] 은(는) 존재하지 않는 노트로 가는 링크")

    # --- 경고 ③: 절 노트가 자기 챕터의 _coverage.md 에 등장하는가(고아 노트) ---
    for n in raw_notes:
        cov_path = root / n['chapter_dir'] / '_coverage.md'
        referenced = cov_path.is_file() and f"[[{n['stem']}]]" in cov_path.read_text(encoding='utf-8')
        if not referenced:
            warn(f"{n['path']} 은(는) {n['chapter_dir']}/_coverage.md 에 없음")

    # --- 경고 ④: 어느 노트·frontmatter 도 참조하지 않는 용어집 항목(용어집 내부 링크는 불인정) ---
    for slug in sorted(glossary_slugs):
        if slug not in referenced_concepts:
            warn(f'용어집 항목 {slug} 을(를) 참조하는 노트가 없음')

    # --- 출력 ---
    graph_dir = root / 'graph'
    graph_dir.mkdir(parents=True, exist_ok=True)
    data = {
        'book': {'slug': book_slug, 'title': book_title, 'vault': vault_name},
        'generated': datetime.datetime.now().isoformat(timespec='seconds'),
        'nodes': nodes,
        'links': links,
    }
    out_path = graph_dir / 'graph-data.js'
    out_path.write_text(
        'window.ATLAS_DATA = ' + json.dumps(data, ensure_ascii=False, indent=2) + ';\n',
        encoding='utf-8',
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
