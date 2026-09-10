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

# 러닝 헤더·푸터와 장·부 표지 — 쪽 furniture 이지 표제·콜아웃·캡션이 아니다(SKILL-009).
# 우면 헤더(`Multi-LLM Architectures   |   323`)는 오른쪽 정렬이라 들여쓰기 15 이상이
# 되어 콜아웃으로 잡히고, 인접한 진짜 콜아웃과 병합되면서 탐침까지 오염시킨다.
RUNNING = re.compile(
    r'^\d+\s*\|\s*Chapter \d+:'       # 좌면: 230   |   Chapter 10: ...
    r'|\|\s*\d+\s*$'                   # 우면: Multi-LLM Architectures   |   323
    r'|^CHAPTER \d+$'                   # 장 표지
    r'|^PART [IVXLC]+$'                 # 부 표지
)
# 목록·코드를 여는 산문 리드인(`Output:`·`Here is an example:`). 들여쓰기 0·마침표 없음·
# 대문자 시작·7단어 이하라 표제 조건을 그대로 통과하지만 표제가 아니다(SKILL-009).
# 콜아웃에는 적용하지 않는다 — 목록을 여는 TIP 상자가 통째로 사라지기 때문이다.
LEADIN = re.compile(r':$')


def config(vault):
    pdf, off = None, 0
    for line in open(os.path.join(vault, '_global', 'config.md'), encoding='utf-8'):
        if line.startswith('- source_pdf:'):
            pdf = line.split(':', 1)[1].strip()
        elif line.startswith('- page_offset:'):
            off = int(line.split(':', 1)[1].split('#')[0].strip())
    if pdf is None:
        return None, off
    return os.path.normpath(os.path.join(vault, pdf)), off


def pages(spec):
    """'371(14행)–375(11행)' → (371, 375) · '284(상단)' → (284, 284)
    · '191 7행–192 10행' → (191, 192) · '192 11–29행' → (192, 192)

    괄호를 걷은 뒤 **줄번호(`NN행`·`NN–NN행`)를 한 번 더 걷어낸다.** 이 볼트의
    커버리지 표는 쪽번호 옆에 괄호 없이 줄번호를 적으므로, 걷어내지 않으면
    마지막 숫자가 끝쪽이 아니라 "끝쪽의 줄번호"가 되어 (191, 10) 같은 뒤집힌
    범위가 나온다. pdftotext 는 그런 범위에 오류 없이 빈 출력을 내므로 후보가
    0건이 되고, 검사는 아무것도 읽지 않은 채 `누락 의심 0건`을 인쇄한다 —
    눈으로는 통과와 구별되지 않는 조용한 실패다(SKILL-008).

    check-chapter.sh 가 같은 표기를 다루려고 쓰는 sed 패턴(SKILL-007)과 같은
    모양을 파이썬 정규식으로 옮긴 것이다.
    """
    spec = re.sub(r'\([^)]*\)', '', spec)
    spec = re.sub(r'\d+(?:\s*[–-]\s*\d+)*\s*행', '', spec)
    nums = re.findall(r'\d+', spec)
    if not nums:
        return None
    return int(nums[0]), int(nums[-1])


LINESPEC = re.compile(r'(\d+)\s*(?:[–-]\s*(\d+)\s*)?행')


def line_bounds(spec):
    """'321 7행–322 35행' → (7, 35) · '192 11–29행' → (11, 29)
    · '173–174 14행' → (None, 14) · '166–169' → (None, None)

    커버리지 표의 구간은 행까지 적히는데 검사는 쪽 단위로만 잘라 읽어서, 앞 절의
    끝과 다음 절의 머리가 이 행의 후보로 딸려 왔다(SKILL-010). 여기서 읽은 경계를
    `candidates()` 에 넘겨 그 범위 밖 줄을 뺀다.

    **읽을 수 없는 표기는 (None, None) 로 둔다.** 잘못 거르면 진짜 발견이 조용히
    사라지지만, 못 거르면 지금까지의 잡음이 남을 뿐이라 안전한 쪽으로 기운다.
    """
    s = spec.replace('(', ' ').replace(')', ' ')
    marks = list(LINESPEC.finditer(s))
    if not marks:
        return (None, None)
    if len(marks) >= 2:
        a = int(marks[0].group(1))
        b = int(marks[-1].group(2) or marks[-1].group(1))
        return (a, b)
    m = marks[0]
    if m.group(2):                      # '11–29행' — 한 쪽 안의 행 범위
        return (int(m.group(1)), int(m.group(2)))
    # 행 표기가 하나뿐이면 뒤에 쪽번호가 더 있는지로 어느 끝인지 가른다.
    return (int(m.group(1)), None) if re.search(r'\d', s[m.end():]) \
        else (None, int(m.group(1)))


def split_pages(text):
    """pdftotext 출력을 쪽별 줄 목록으로 나눈다(쪽 안에서 행을 세야 하므로)."""
    chunks = text.split('\f')
    if chunks and chunks[-1] == '':
        chunks.pop()
    return [c.split('\n') for c in chunks]


def extract(pdf, first, last):
    out = subprocess.run(
        ['pdftotext', '-layout', '-f', str(first), '-l', str(last), pdf, '-'],
        capture_output=True, text=True)
    return out.stdout.split('\n')


def extract_by_page(pdf, first, last):
    """쪽별 줄 목록 — 행 경계로 자르려면 쪽 안에서 행을 세야 한다(SKILL-010)."""
    out = subprocess.run(
        ['pdftotext', '-layout', '-f', str(first), '-l', str(last), pdf, '-'],
        capture_output=True, text=True)
    return split_pages(out.stdout)


def candidates(lines, lo=None, hi=None):
    """(종류, 표시문자열, 탐침목록) 목록을 낸다.

    `lo`·`hi` 는 이 쪽 안에서 검사할 1-기반 행 범위다(SKILL-010). None 이면 그쪽
    끝은 제한하지 않는다.
    """
    found = []
    for idx, line in enumerate(lines):
        if not line.strip():
            continue
        if lo is not None and idx + 1 < lo:
            continue
        if hi is not None and idx + 1 > hi:
            continue
        indent = len(line) - len(line.lstrip())
        text = line.strip()
        if RUNNING.search(text):
            continue
        m = CAPTION.search(text)
        if m:
            found.append(('캡션', f"{m.group(1)} {m.group(2)}", [m.group(2)], idx))
            continue
        if indent >= 15:
            probes = [w for w in re.findall(r'[A-Z][\w.\-]{2,}|[a-z_]+\(\)|\d+[\w-]*', text)
                      if w.lower() not in STOP]
            if probes:
                found.append(('콜아웃', text[:60], probes[:4], idx))
            else:
                found.append(('콜아웃', text[:60], [], idx))
        elif indent == 0 and len(text) <= 60 and not text.endswith('.') \
                and not LEADIN.search(text) \
                and text[0].isupper() and len(text.split()) <= 7:
            found.append(('표제', text, [text], idx))
    # 콜아웃이 이어지면 하나로 접는다(콜아웃은 여러 줄이다) — 단, 원문에서 실제로
    # 인접한(빈 줄 하나 정도 차이) 줄끼리만. found 는 후보에 안 걸려 건너뛴 줄을
    # 그냥 스킵하므로, 원문 인덱스를 안 보면 열 줄 떨어진 별개 콜아웃도 "바로 옆"
    # 으로 보여 잘못 합쳐진다.
    ADJACENT = 2
    merged, prev = [], None
    for kind, label, probes, idx in found:
        if kind == '콜아웃' and prev and prev[0] == '콜아웃' and idx - prev[3] <= ADJACENT:
            prev[2].extend(probes)
            prev[3] = idx
            continue
        prev = [kind, label, list(probes), idx]
        merged.append(prev)
    return [(kind, label, probes) for kind, label, probes, _ in merged]


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

    cov = os.path.join(chdir, '_coverage.md')
    if not os.path.isfile(cov):
        # 아직 착수 안 한 챕터의 정상 상태다 — 검사할 게 없을 뿐 오류가 아니다.
        print(f"audit-delivery: _coverage.md 없음(검사 대상 없음, 건너뜀): {cov}", file=sys.stderr)
        return 0

    pdf, off = config(vault)
    if not pdf:
        print(f"audit-delivery: {os.path.join(vault, '_global', 'config.md')} 에 "
              "source_pdf 줄이 없음", file=sys.stderr)
        return 1

    ok, miss, unknown = [], [], []
    trimmed = 0
    for line in open(cov, encoding='utf-8'):
        m = ROW.match(line)
        if not m:
            continue
        rng, notecell = m.group(1), m.group(2)
        pg = pages(rng)
        if not pg:
            continue
        if pg[0] > pg[1]:
            # 여기서 걸러내지 않으면 pdftotext 가 빈 출력을 내고 그 행은 후보 0건이
            # 되어, 검사하지 않은 것과 통과한 것이 구별되지 않는다(SKILL-008).
            unknown.append((rng, '범위오류',
                            f'쪽 범위가 뒤집혔다({pg[0]}→{pg[1]}) — 이 행은 검사하지 못했다'))
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
        # 쪽 단위로만 자르면 앞 절의 끝과 다음 절의 머리가 딸려 온다. 커버리지가
        # 적어 둔 행 경계로 첫 쪽의 앞부분과 끝 쪽의 뒷부분을 잘라낸다(SKILL-010).
        lo, hi = line_bounds(rng)
        pages_ = extract_by_page(pdf, pg[0] + off, pg[1] + off)
        cands, wide = [], 0
        for i, plines in enumerate(pages_):
            a = lo if i == 0 else None
            b = hi if i == len(pages_) - 1 else None
            cands += candidates(plines, a, b)
            if a is not None or b is not None:
                wide += len(candidates(plines)) - len(candidates(plines, a, b))
        trimmed += wide
        for kind, label, probes in cands:
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
    if trimmed:
        # 조용히 줄이지 않는다 — 행 경계가 틀리면 진짜 후보가 사라지므로 몇 건을
        # 뺐는지 항상 보인다(SKILL-010).
        print(f"행 경계 밖   {trimmed}건 제외(커버리지의 NN행 표기 기준)")
    print(f"확인 불가   {len(unknown)}건")
    for rng, kind, label in unknown:
        print(f"    p.{rng} [{kind}] {label}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
