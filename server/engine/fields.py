"""Identify TOC fields without relying on their cached, visible text."""

import re

from docx.oxml.ns import qn


def _is_toc_instruction(instruction: str) -> bool:
    return re.match(r"^\s*TOC(?:\s|\\|$)", instruction, re.IGNORECASE) is not None


def toc_paragraph_elements(doc) -> set:
    """Return paragraphs occupied by simple or complex TOC fields.

    Complex field instructions may span runs, and their cached results may span
    paragraphs and contain nested PAGEREF fields. Scan the body XML so fields
    inside Word content controls and tables are detected as well.
    """
    paragraphs = set()
    stack = []
    for element in doc.element.body.iter():
        if element.tag == qn("w:p"):
            for field in stack:
                field["paragraphs"].add(element)
        elif element.tag == qn("w:fldSimple"):
            if _is_toc_instruction(element.get(qn("w:instr"), "")):
                paragraphs.update(element.iter(qn("w:p")))
                paragraphs.update(element.iterancestors(qn("w:p")))
        elif element.tag == qn("w:fldChar"):
            kind = element.get(qn("w:fldCharType"))
            if kind == "begin":
                stack.append({
                    "instruction": [],
                    "collecting": True,
                    "paragraphs": set(element.iterancestors(qn("w:p"))),
                })
            elif stack and kind == "separate":
                stack[-1]["collecting"] = False
            elif stack and kind == "end":
                field = stack.pop()
                if _is_toc_instruction("".join(field["instruction"])):
                    paragraphs.update(field["paragraphs"])
        elif element.tag == qn("w:instrText"):
            if stack and stack[-1]["collecting"]:
                stack[-1]["instruction"].append(element.text or "")
    return paragraphs
