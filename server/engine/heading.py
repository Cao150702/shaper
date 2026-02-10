from __future__ import annotations

import re


SPECIAL_LEVEL1 = {
    "摘要",
    "ABSTRACT",
    "引言",
    "绪论",
    "结论",
    "参考文献",
    "致谢",
    "目录",
}


def detect_heading_level_from_style(style_name: str | None) -> int | None:
    if not style_name:
        return None
    for token in ("Heading", "标题"):
        if token in style_name:
            digits = "".join(ch for ch in style_name if ch.isdigit())
            if digits:
                return int(digits)
    return None


def detect_heading_level_from_text(text: str) -> int | None:
    raw = text.strip()
    if not raw or len(raw) > 30:
        return None
    if raw in SPECIAL_LEVEL1:
        return 1

    patterns: list[tuple[str, int]] = [
        (r"^第[一二三四五六七八九十百千0-9]+章", 1),
        (r"^[一二三四五六七八九十]+、", 1),
        (r"^\d+\.\d+\.\d+\s*", 3),
        (r"^\d+\.\d+\s*", 2),
        (r"^\d+[、.]\s*", 1),
        (r"^（[一二三四五六七八九十]+）", 2),
        (r"^\([一二三四五六七八九十]+\)", 2),
        (r"^（\d+）", 3),
        (r"^\(\d+\)", 3),
        (r"^\d+）", 3),
        (r"^[A-Z]\.\s*", 2),
    ]
    for pattern, level in patterns:
        if re.match(pattern, raw):
            return level
    return None


def detect_heading_level(paragraph) -> int | None:
    style_name = paragraph.style.name if paragraph.style else None
    level = detect_heading_level_from_style(style_name)
    if level:
        return level
    return detect_heading_level_from_text(paragraph.text)
