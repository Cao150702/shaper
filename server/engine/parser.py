from __future__ import annotations

from dataclasses import dataclass
import io

from docx import Document


@dataclass
class DocumentSnapshot:
    doc: Document
    byte_size: int


def read_docx_bytes(data: bytes) -> DocumentSnapshot:
    doc = Document(io.BytesIO(data))
    return DocumentSnapshot(doc=doc, byte_size=len(data))
