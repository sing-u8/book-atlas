"""Regression checks for quality-gate blind spots and false positives."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('quality', Path(__file__).parents[1] / 'check-quality.py')
quality = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quality)

NOTE = '''---
concepts: [retrieval]
---
## 한눈에 보기
| 질문 | 핵심 답 |
|---|---|
| 왜 검색하나? | 답할 자료를 찾는다. |
## 왜 이 절인가
사내 문서에서 답을 찾는다.
## 본문 정리
**[[retrieval]]**(= 질문과 관련된 문서를 찾는 단계)를 수행한다.
## 개념
| retrieval | 자료 검색 | [[_glossary#retrieval]] |
## 연결
- [[retrieval]] — 관련 개념
'''


class QualityTests(unittest.TestCase):
    def inspect(self, text, glossary=None):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / '01-note.md'
            path.write_text(text, encoding='utf-8')
            return quality.inspect_note(path, glossary or [('retrieval', '01-note')])

    def test_valid_note(self):
        self.assertEqual(self.inspect(NOTE), [])

    def test_alias_and_question_formatting(self):
        text = NOTE.replace('왜 검색하나?', '**[[retrieval|검색]]은 왜 필요한가?**')
        text = text.replace('**[[retrieval]]**(=', '**[[retrieval|검색]]**(=')
        self.assertEqual(self.inspect(text), [])

    def test_list_table_fails(self):
        self.assertTrue(any(level == 'FAIL' for level, _ in self.inspect(NOTE.replace('왜 검색하나?', '검색'))))

    def test_empty_answer_and_empty_table_fail(self):
        for text in (NOTE.replace('답할 자료를 찾는다.', ''), NOTE.replace('| 왜 검색하나? | 답할 자료를 찾는다. |', '')):
            self.assertTrue(any(level == 'FAIL' for level, _ in self.inspect(text)))

    def test_summary_only_link_cannot_satisfy_body(self):
        text = NOTE.replace('**[[retrieval]]**(= 질문과 관련된 문서를 찾는 단계)를 수행한다.', '검색한다.')
        text = text.replace('왜 검색하나?', '[[retrieval|검색]]은 왜 필요한가?')
        self.assertTrue(any(level == 'FAIL' and '본문 링크' in msg for level, msg in self.inspect(text)))

    def test_code_and_memo_links_cannot_satisfy_body(self):
        text = NOTE.replace('**[[retrieval]]**(= 질문과 관련된 문서를 찾는 단계)를 수행한다.', '```mermaid\nA[[retrieval]]\n```')
        text += quality.SEP + '\n## 내 메모\n**[[retrieval]]**(= 검색)'
        self.assertTrue(any(level == 'FAIL' and '본문 링크' in msg for level, msg in self.inspect(text)))

    def test_other_valid_explanation_is_review_not_failure(self):
        result = self.inspect(NOTE.replace('**[[retrieval]]**(= 질문과 관련된 문서를 찾는 단계)', '[[retrieval]]은 질문과 관련된 문서를 찾는 단계다. 이를'))
        self.assertTrue(any(level == 'REVIEW' for level, _ in result))
        self.assertFalse(any(level == 'FAIL' for level, _ in result))

    def test_repeat_term_does_not_require_redefinition(self):
        text = NOTE.replace('**[[retrieval]]**(= 질문과 관련된 문서를 찾는 단계)', '[[retrieval]]')
        self.assertEqual(self.inspect(text, [('retrieval', '00-earlier')]), [])

    def test_user_memo_does_not_change_sections(self):
        text = NOTE + quality.SEP + '\n## 한눈에 보기\n| 항목 | 목록 |\n## 본문 정리\n[[unknown]]'
        self.assertEqual(self.inspect(text), [])

    def test_multiline_definition_and_escaped_pipe(self):
        text = NOTE.replace('질문과 관련된 문서를 찾는 단계', '질문과 관련된\n문서를 찾는 단계')
        text = text.replace('답할 자료를 찾는다.', r'A \| B 중 자료를 찾는다.')
        self.assertEqual(self.inspect(text), [])


if __name__ == '__main__':
    unittest.main()
