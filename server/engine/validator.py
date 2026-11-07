from __future__ import annotations

from typing import Any

from docx.shared import Pt

from .fields import toc_paragraph_elements
from .heading import detect_heading_level, find_document_title
from .parser import DocumentSnapshot


def _iter_paragraphs(doc):
    for paragraph in doc.paragraphs:
        yield paragraph
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    yield paragraph


def build_violation_report(document: DocumentSnapshot, rule: dict[str, Any]) -> dict[str, Any]:
    body_rule = rule.get("body", {})
    body_font = body_rule.get("font", "宋体")
    body_size = body_rule.get("size", 12)
    line_spacing = body_rule.get("line_spacing", 1.5)
    indent_em = body_rule.get("first_line_indent_em", 2)

    violations: list[dict[str, Any]] = []
    seen_levels: set[int] = set()
    heading_gap_reported = False

    expected_indent = Pt(body_size * indent_em)
    toc_paragraphs = toc_paragraph_elements(document.doc)
    title = (
        find_document_title(document.doc, toc_paragraphs)
        if rule.get("document_title") else None
    )

    for paragraph in _iter_paragraphs(document.doc):
        if paragraph._p in toc_paragraphs:
            continue
        if title is not None and paragraph._p is title._p:
            continue
        text = paragraph.text.strip()
        if not text:
            continue

        level = detect_heading_level(paragraph)
        if level:
            if level > 1 and (level - 1) not in seen_levels and not heading_gap_reported:
                violations.append(
                    {
                        "title": "标题层级不连续",
                        "detail": f"检测到 {level} 级标题，但前面没有 {level - 1} 级标题。",
                        "severity": "medium",
                    }
                )
                heading_gap_reported = True
            seen_levels.add(level)
            continue

        run_fonts = {
            run.font.name
            for run in paragraph.runs
            if run.text.strip() and run.font.name
        }
        if run_fonts and body_font not in run_fonts:
            violations.append(
                {
                    "title": "正文字体不一致",
                    "detail": f"检测到字体 {', '.join(sorted(run_fonts))}。期望统一为 {body_font}。",
                    "severity": "high",
                }
            )
            run_fonts = set()

        spacing = paragraph.paragraph_format.line_spacing
        spacing_value = None
        if isinstance(spacing, (int, float)):
            spacing_value = float(spacing)
        elif spacing is not None and hasattr(spacing, "pt"):
            spacing_value = float(spacing.pt)
        if spacing_value and abs(spacing_value - line_spacing) > 0.1:
            violations.append(
                {
                    "title": "行距不规范",
                    "detail": f"当前行距为 {spacing_value:.1f}，期望 {line_spacing:.1f}。",
                    "severity": "low",
                }
            )

        indent = paragraph.paragraph_format.first_line_indent
        if indent and abs(indent.pt - expected_indent.pt) > 1:
            violations.append(
                {
                    "title": "首行缩进不规范",
                    "detail": f"当前首行缩进约为 {indent.pt:.1f}pt，期望 {expected_indent.pt:.1f}pt。",
                    "severity": "low",
                }
            )

    return {
        "document": {"byte_size": document.byte_size},
        "summary": {"violations": len(violations)},
        "violations": violations[:30],
        "rule": rule,
    }

