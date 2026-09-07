#!/usr/bin/env python3
"""Read-only note quality checks. Exit 0: no FAIL, 2: FAIL, 1: input error.

REVIEW identifies candidates requiring reading, never a proven omission.
Uses only the standard library; accepts a note, chapter, or vault.
"""
import re
import sys
from pathlib import Path

SEP = '<!-- ==== 아래는 내 메모 · 스킬 수정 금지 ==== -->'
LINK = re.compile(r'\[\[([^\]]+)\]\]')


def prose(text):
    text = text.split(SEP, 1)[0]
    text = re.sub(r'\A---\s*\n.*?\n---\s*\n', '', text, count=1, flags=re.S)
    out, fence = [], None
    for line in text.splitlines():
        mark = re.match(r'^\s*(`{3,}|~{3,})', line)
        if mark:
            token = mark[1]
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence):
                fence = None
            continue
        if fence is None:
            out.append(line)
    return '\n'.join(out)


def sections(text):
    result, current = {}, None
    for line in prose(text).splitlines():
        h = re.match(r'^## (.+?)\s*$', line)
        if h:
            current = h[1]
            result.setdefault(current, [])
        elif current:
            result[current].append(line)
    return {key: '\n'.join(lines) for key, lines in result.items()}


def target(raw):
    return raw.split('|', 1)[0].split('#', 1)[0].removesuffix('.md').strip()


def cells(line):
    # Protect wikilink aliases and escaped pipes before splitting a table row.
    protected = LINK.sub(lambda m: m[0].replace('|', '\0'), line.strip())
    return [s.replace('\0', '|').strip() for s in
            re.split(r'(?<!\\)\|', protected.strip('|'))]


def inspect_note(path, glossary):
    text = path.read_text(encoding='utf-8')
    blocks = sections(text)
    result = []
    rows = [cells(s) for s in blocks.get('한눈에 보기', '').splitlines()
            if s.strip().startswith('|')]
    if len(rows) < 3 or not all(re.fullmatch(r':?-{3,}:?', c) for c in rows[1]):
        result.append(('FAIL', '질문표: 헤더·구분행·질문/답 행이 필요함'))
    else:
        for row in rows[2:]:
            question = LINK.sub(lambda m: m[1].split('|')[-1], row[0])
            question = question.strip().strip('*_`').strip()
            if len(row) != 2 or not question.endswith(('?', '？')) or not row[1]:
                result.append(('FAIL', f'질문표: 질문 → 답 2열 필요: {row[0]}'))

    body = '\n'.join(blocks.get(k, '') for k in ('왜 이 절인가', '본문 정리'))
    links = {target(m[1]) for m in LINK.finditer(body)}
    fm = re.match(r'\A---\s*\n(.*?)\n---', text, re.S)
    concept_match = re.search(r'^concepts:\s*\[([^\]]*)\]\s*$', fm[1], re.M) if fm else None
    if not concept_match:
        result.append(('FAIL', 'concepts: 인라인 배열 형식을 확인할 수 없음'))
    else:
        for term in concept_match[1].split(','):
            term = term.strip().strip('\"\'')
            if term and term not in links:
                result.append(('FAIL', f'본문 링크: [[{term}]]가 도입/본문에 없음'))

    for term, first in glossary:
        if '/' in first:
            is_first = path.as_posix().endswith('/' + first + '.md')
        else:
            is_first = path.stem == first
        if not is_first:
            continue
        # `**[[top-p]]**(`top_p`, = …)` 처럼 괄호 앞부분에 원어·별칭이 먼저 오는 형태도
        # 인라인 풀이다 — `(=` 만 찾으면 그런 자리를 REVIEW 로 잘못 올린다.
        inline = re.search(r'\[\[' + re.escape(term) +
                           r'(?:\|[^\]]+)?\]\](?:\*\*)?\s*\([^)]*=\s*[^)]+\)', body)
        if not inline:
            result.append(('REVIEW', f'최초 풀이: {term} — 주변 산문/표의 설명과 최초 위치를 확인'))
    return result


def main():
    if len(sys.argv) != 2:
        print('usage: check-quality.py <note.md|chapter-dir|vault-root>', file=sys.stderr)
        return 1
    scope = Path(sys.argv[1]).resolve()
    if not scope.exists():
        print(f'입력 없음: {scope}', file=sys.stderr)
        return 1
    root = scope.parent if scope.is_file() else scope
    while not (root / '_glossary.md').is_file():
        if root == root.parent:
            print('용어집을 찾을 수 없음', file=sys.stderr)
            return 1
        root = root.parent
    glossary = []
    term = None
    for line in prose((root / '_glossary.md').read_text(encoding='utf-8')).splitlines():
        h = re.match(r'^## ([a-z0-9-]+)(?:\s|$)', line)
        if h:
            term = h[1]
        first = re.match(r'^- 처음 나온 곳:\s*\[\[([^\]]+)\]\]', line)
        if first and term:
            glossary.append((term, target(first[1])))
    notes = [scope] if scope.is_file() else sorted(
        p for p in scope.rglob('*.md')
        if re.match(r'^\d', p.name) and p.parent.name.startswith('chapter-'))
    if not notes:
        print('검사할 절 노트가 없음', file=sys.stderr)
        return 1
    failures = reviews = 0
    for note in notes:
        for level, message in inspect_note(note, glossary):
            failures += level == 'FAIL'
            reviews += level == 'REVIEW'
            print(f'{level} {note.relative_to(root)}: {message}')
    print(f'quality: notes={len(notes)} FAIL={failures} REVIEW={reviews}; 원문 정확도·완전성은 별도 대조 필요')
    return 2 if failures else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, UnicodeError) as exc:
        print(f'입력 오류: {exc}', file=sys.stderr)
        sys.exit(1)
