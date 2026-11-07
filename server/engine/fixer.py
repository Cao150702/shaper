from __future__ import annotations

from typing import Any
import io

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt

from .fields import toc_paragraph_elements
from .heading import detect_heading_level, find_document_title


def _iter_paragraphs(doc):
    for paragraph in doc.paragraphs:
        yield paragraph
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    yield paragraph


def _set_run_font(run, font_name: str, size_pt: int, bold: bool | None = None):
    run.font.name = font_name
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.rFonts
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:ascii"), font_name)
    rfonts.set(qn("w:hAnsi"), font_name)
    rfonts.set(qn("w:eastAsia"), font_name)
    run.font.size = Pt(size_pt)
    if bold is not None:
        run.bold = bold


def _set_paragraph_line_spacing(paragraph, line_spacing: float):
    paragraph.paragraph_format.line_spacing = line_spacing
    paragraph.paragraph_format.space_before = Pt(0)
    paragraph.paragraph_format.space_after = Pt(0)


def _apply_body_rule(paragraph, rule: dict[str, Any]):
    body = rule.get("body", {})
    font = body.get("font", "宋体")
    size = body.get("size", 12)
    line_spacing = body.get("line_spacing", 1.5)
    indent_em = body.get("first_line_indent_em", 2)

    _set_paragraph_line_spacing(paragraph, line_spacing)
    paragraph.paragraph_format.first_line_indent = Pt(size * indent_em)

    for run in paragraph.runs:
        if not run.text.strip():
            continue
        _set_run_font(run, font, size)


def _apply_heading_rule(paragraph, rule: dict[str, Any], level: int):
    titles = rule.get("titles", [])
    target = next((item for item in titles if item.get("level") == level), None)
    if not target:
        return

    font = target.get("font", "黑体")
    size = target.get("size", 16)
    bold = target.get("bold", True)
    alignment = target.get("alignment", "center")

    if alignment == "center":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    else:
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT

    _set_paragraph_line_spacing(paragraph, 1.5)

    for run in paragraph.runs:
        if not run.text.strip():
            continue
        _set_run_font(run, font, size, bold)

    for style_name in (f"Heading {level}", f"标题 {level}"):
        try:
            paragraph.style = style_name
            break
        except Exception:
            continue


def _apply_document_title(paragraph, rule: dict[str, Any]):
    font = rule.get("font", "黑体")
    size = rule.get("size", 18)
    bold = rule.get("bold", True)
    alignment = rule.get("alignment", "center")

    if alignment == "center":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    else:
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT

    _set_paragraph_line_spacing(paragraph, 1.5)
    paragraph.paragraph_format.first_line_indent = Pt(0)

    for run in paragraph.runs:
        if not run.text.strip():
            continue
        _set_run_font(run, font, size, bold)


def _add_field(paragraph, field_instr: str):
    run = paragraph.add_run()
    fld_char_begin = OxmlElement("w:fldChar")
    fld_char_begin.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = field_instr
    fld_char_separate = OxmlElement("w:fldChar")
    fld_char_separate.set(qn("w:fldCharType"), "separate")
    fld_char_end = OxmlElement("w:fldChar")
    fld_char_end.set(qn("w:fldCharType"), "end")
    run._r.append(fld_char_begin)
    run._r.append(instr_text)
    run._r.append(fld_char_separate)
    run._r.append(fld_char_end)


def _ensure_toc(doc: Document):
    if toc_paragraph_elements(doc):
        return
    toc_field = r'TOC \o "1-3" \h \z \u'
    if doc.paragraphs:
        first = doc.paragraphs[0]
        insert_target = first.insert_paragraph_before()
    else:
        insert_target = doc.add_paragraph()
    _add_field(insert_target, toc_field)


def _ensure_page_number(section, position: str):
    footer = section.footer
    if footer.paragraphs:
        paragraph = footer.paragraphs[0]
        paragraph.text = ""
    else:
        paragraph = footer.add_paragraph()

    if position == "bottom_center":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    else:
        paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT

    _add_field(paragraph, "PAGE")


def apply_fixes(data: bytes, rule: dict[str, Any]) -> bytes:
    doc = Document(io.BytesIO(data))
    page = rule.get("page", {})
    margin_cm = page.get("margin_cm", 2.5)

    for section in doc.sections:
        margin = Cm(margin_cm)
        section.top_margin = margin
        section.bottom_margin = margin
        section.left_margin = margin
        section.right_margin = margin

        if page.get("footer", True):
            _ensure_page_number(section, page.get("page_number", "bottom_center"))

    if rule.get("toc", {}).get("enable", False):
        _ensure_toc(doc)

    toc_paragraphs = toc_paragraph_elements(doc)
    document_title = rule.get("document_title")
    title = find_document_title(doc, toc_paragraphs) if document_title else None

    for paragraph in _iter_paragraphs(doc):
        if paragraph._p in toc_paragraphs:
            continue
        text = paragraph.text.strip()
        if not text:
            continue

        if title is not None and paragraph._p is title._p:
            _apply_document_title(paragraph, document_title)
            continue

        level = detect_heading_level(paragraph)
        if level:
            _apply_heading_rule(paragraph, rule, level)
        else:
            _apply_body_rule(paragraph, rule)

    output = io.BytesIO()
    doc.save(output)
    return output.getvalue()

