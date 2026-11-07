"""Synthetic DOCX regressions; no user files or network services required."""

import copy
import io
import json
from pathlib import Path
import unittest
import zipfile

from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt
from lxml import etree

from engine.fixer import apply_fixes
from engine.parser import read_docx_bytes
from engine.validator import build_violation_report


TEMPLATES = json.loads(
    (Path(__file__).resolve().parents[1] / "rules/templates.json").read_text()
)


def save(document):
    output = io.BytesIO()
    document.save(output)
    return output.getvalue()


def field_char(paragraph, kind):
    element = OxmlElement("w:fldChar")
    element.set(qn("w:fldCharType"), kind)
    paragraph.add_run()._r.append(element)


def instruction(paragraph, text):
    element = OxmlElement("w:instrText")
    element.set(qn("xml:space"), "preserve")
    element.text = text
    paragraph.add_run()._r.append(element)


def complex_toc(paragraph, chunks=(r'TOC \o "1-3" \h \z \u',)):
    field_char(paragraph, "begin")
    for chunk in chunks:
        instruction(paragraph, chunk)
    field_char(paragraph, "separate")
    paragraph.add_run("第一章 引言\t1")
    field_char(paragraph, "end")


def simple_toc(paragraph):
    element = OxmlElement("w:fldSimple")
    element.set(qn("w:instr"), r' TOC \o "1-3" ')
    paragraph._p.append(element)


class FixerTests(unittest.TestCase):
    def setUp(self):
        self.rule = copy.deepcopy(TEMPLATES[0])

    def fix(self, document):
        return Document(io.BytesIO(apply_fixes(save(document), self.rule)))

    def paper(self):
        document = Document()
        document.add_paragraph("论文排版测试")
        document.add_paragraph("第一章 引言")
        document.add_paragraph("这是一段用于验证正文格式的合成文本。")
        return document

    def assert_title(self, paragraph, expected=None):
        expected = expected or self.rule["document_title"]
        self.assertEqual(paragraph.alignment, WD_ALIGN_PARAGRAPH.CENTER)
        self.assertEqual(paragraph.paragraph_format.first_line_indent, Pt(0))
        for run in paragraph.runs:
            if run.text.strip():
                self.assertEqual(run.font.name, expected["font"])
                self.assertEqual(run.font.size, Pt(expected["size"]))
                self.assertEqual(run.bold, expected["bold"])
                self.assertEqual(
                    run._r.rPr.rFonts.get(qn("w:eastAsia")), expected["font"]
                )

    def test_title_body_heading_and_table_styles(self):
        document = self.paper()
        document.paragraphs[0].add_run("副标题")
        document.paragraphs[0].paragraph_format.first_line_indent = Pt(24)
        document.add_paragraph("1.1 研究背景")
        document.add_paragraph("1.1.1 研究范围")
        document.add_table(rows=1, cols=1).cell(0, 0).text = "表格正文"
        output = self.fix(document)
        title, heading, body, subheading, subsubheading = output.paragraphs[1:]
        self.assert_title(title)
        self.assertEqual(title.style.name, "Normal")
        for paragraph, level, size in (
            (heading, 1, 16), (subheading, 2, 14), (subsubheading, 3, 12)
        ):
            self.assertEqual(paragraph.style.name, f"Heading {level}")
            self.assertEqual(paragraph.runs[0].font.name, "黑体")
            self.assertEqual(paragraph.runs[0].font.size, Pt(size))
            self.assertTrue(paragraph.runs[0].bold)
        for paragraph in (body, output.tables[0].cell(0, 0).paragraphs[0]):
            self.assertEqual(paragraph.runs[0].font.name, "宋体")
            self.assertEqual(paragraph.runs[0].font.size, Pt(12))
            self.assertEqual(paragraph.paragraph_format.line_spacing, 1.5)
            self.assertEqual(paragraph.paragraph_format.first_line_indent, Pt(24))

    def test_title_style_and_leading_blank_are_preserved(self):
        document = Document()
        document.add_paragraph()
        title = document.add_paragraph("论文标题", style="Title")
        title.paragraph_format.first_line_indent = Pt(24)
        output = self.fix(document)
        self.assert_title(output.paragraphs[-1])
        self.assertEqual(output.paragraphs[-1].style.name, "Title")

    def test_repeat_fixes_are_stable_for_both_templates(self):
        for rule in TEMPLATES:
            with self.subTest(template=rule["name"]):
                data = save(self.paper())
                previous_xml = None
                for _ in range(3):
                    data = apply_fixes(data, rule)
                    with zipfile.ZipFile(io.BytesIO(data)) as archive:
                        self.assertIsNone(archive.testzip())
                    output = Document(io.BytesIO(data))
                    self.assert_title(output.paragraphs[1], rule["document_title"])
                    toc = output.element.body.xpath(".//w:instrText")
                    self.assertEqual([node.text for node in toc],
                                     [r'TOC \o "1-3" \h \z \u'])
                    if previous_xml is not None:
                        self.assertEqual(output.element.body.xml, previous_xml)
                    previous_xml = output.element.body.xml
                    report = build_violation_report(read_docx_bytes(data), rule)
                    self.assertEqual(report["summary"]["violations"], 0)

    def test_existing_complex_toc_after_title_is_preserved(self):
        document = self.paper()
        paragraph = document.add_paragraph()
        complex_toc(paragraph)
        paragraph.runs[-2].font.name = "Arial"
        paragraph.runs[-2].font.size = Pt(9)
        paragraph.paragraph_format.first_line_indent = Pt(8)
        before = paragraph._p.xml
        output = self.fix(document)
        self.assertEqual(len(output.paragraphs), len(document.paragraphs))
        self.assertEqual(output.paragraphs[-1]._p.xml, before)
        self.assert_title(output.paragraphs[0])

    def test_split_lowercase_instruction_and_multiline_results(self):
        document = Document()
        start = document.add_paragraph()
        field_char(start, "begin")
        instruction(start, " to")
        instruction(start, 'c \\o "1-3" ')
        field_char(start, "separate")
        document.styles.add_style("TOC 1", WD_STYLE_TYPE.PARAGRAPH)
        result = document.add_paragraph("第一章 引言", style="TOC 1")
        field_char(result, "begin")
        instruction(result, "PAGEREF _Toc1")
        field_char(result, "separate")
        result.add_run("1")
        field_char(result, "end")
        end = document.add_paragraph("第二章 方法\t2", style="TOC 1")
        field_char(end, "end")
        before = [p._p.xml for p in document.paragraphs]
        document.add_paragraph("论文标题")
        output = self.fix(document)
        self.assertEqual([p._p.xml for p in output.paragraphs[:3]], before)
        self.assertEqual(output.paragraphs[1].style.name, "TOC 1")
        self.assert_title(output.paragraphs[-1])

    def test_existing_simple_toc(self):
        document = self.paper()
        paragraph = document.add_paragraph()
        simple_toc(paragraph)
        before = paragraph._p.xml
        output = self.fix(document)
        self.assertEqual(len(output.paragraphs), len(document.paragraphs))
        self.assertEqual(output.paragraphs[-1]._p.xml, before)

    def test_existing_toc_inside_content_control(self):
        document = self.paper()
        paragraph = document.add_paragraph()
        complex_toc(paragraph)
        sdt = OxmlElement("w:sdt")
        content = OxmlElement("w:sdtContent")
        content.append(paragraph._p)
        sdt.append(content)
        document.element.body.insert(0, sdt)
        before = etree.tostring(sdt)
        output = self.fix(document)
        self.assertEqual(len(output.paragraphs), 3)
        self.assertEqual(etree.tostring(output.element.body.xpath("./w:sdt")[0]), before)
        self.assert_title(output.paragraphs[0])

    def test_existing_toc_inside_table(self):
        document = self.paper()
        paragraph = document.add_table(rows=1, cols=1).cell(0, 0).paragraphs[0]
        complex_toc(paragraph)
        before = paragraph._p.xml
        output = self.fix(document)
        self.assertEqual(len(output.paragraphs), 3)
        self.assertEqual(output.tables[0].cell(0, 0).paragraphs[0]._p.xml, before)

    def test_visible_toc_text_does_not_suppress_field(self):
        for text in ("TOC overview", "TOC", "目录"):
            with self.subTest(text=text):
                document = Document()
                document.add_paragraph(text)
                output = self.fix(document)
                self.assertEqual(len(output.element.body.xpath(".//w:instrText")), 1)

    def test_non_toc_field_is_not_mistaken_for_toc(self):
        document = self.paper()
        paragraph = document.add_paragraph()
        complex_toc(paragraph, ('NOTOC',))
        output = self.fix(document)
        self.assertEqual(len(output.element.body.xpath(".//w:instrText")), 2)

    def test_empty_document_has_one_toc_after_repeat(self):
        output = self.fix(self.fix(Document()))
        self.assertEqual(len(output.paragraphs), 1)
        self.assertEqual(len(output.element.body.xpath(".//w:instrText")), 1)

    def test_toc_disabled_does_not_insert_or_restyle_existing_toc(self):
        self.rule["toc"]["enable"] = False
        document = self.paper()
        self.assertEqual(len(self.fix(document).paragraphs), 3)
        paragraph = document.add_paragraph()
        complex_toc(paragraph)
        before = paragraph._p.xml
        self.assertEqual(self.fix(document).paragraphs[-1]._p.xml, before)

    def test_first_heading_is_not_document_title(self):
        for style, text in (("Normal", "第一章 引言"), ("Heading 2", "研究背景")):
            with self.subTest(style=style):
                document = Document()
                document.add_paragraph(text, style=style)
                output = self.fix(document)
                self.assertNotEqual(output.paragraphs[1].runs[0].font.size, Pt(18))
                self.assertTrue(output.paragraphs[1].style.name.startswith("Heading"))

    def test_long_body_is_not_document_title(self):
        document = Document()
        document.add_paragraph("这是较长的正文段落。" * 6)
        self.assertEqual(self.fix(document).paragraphs[1].runs[0].font.size, Pt(12))

    def test_without_title_rule_first_paragraph_uses_body_format(self):
        del self.rule["document_title"]
        output = self.fix(self.paper())
        self.assertEqual(output.paragraphs[1].runs[0].font.name, "宋体")

    def test_validator_still_reports_bad_body_after_title(self):
        document = self.paper()
        body = document.paragraphs[-1]
        body.runs[0].font.name = "Arial"
        report = build_violation_report(read_docx_bytes(save(document)), self.rule)
        self.assertIn("正文字体不一致", [v["title"] for v in report["violations"]])


if __name__ == "__main__":
    unittest.main()
