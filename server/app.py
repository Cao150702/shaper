from __future__ import annotations

import io
import json
import zipfile
from typing import Any

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse

from engine.validator import build_violation_report
from engine.fixer import apply_fixes
from engine.parser import read_docx_bytes
from pathlib import Path

app = FastAPI(title="Shaper Local Server", version="0.1.0")


def _parse_rule(rule_json: str | None) -> dict[str, Any]:
    if not rule_json:
        return {}
    try:
        return json.loads(rule_json)
    except json.JSONDecodeError:
        return {}


@app.get("/templates")
async def templates():
    templates_path = Path(__file__).resolve().parent / "rules" / "templates.json"
    if not templates_path.exists():
        return JSONResponse([])
    data = json.loads(templates_path.read_text(encoding="utf-8"))
    return JSONResponse(data)


@app.post("/analyze")
async def analyze(file: UploadFile = File(...), rule: str = Form(None)):
    rule_data = _parse_rule(rule)
    doc_bytes = await file.read()
    document = read_docx_bytes(doc_bytes)
    report = build_violation_report(document, rule_data)
    return JSONResponse(report)


@app.post("/fix")
async def fix(file: UploadFile = File(...), rule: str = Form(None)):
    rule_data = _parse_rule(rule)
    doc_bytes = await file.read()
    fixed_bytes = apply_fixes(doc_bytes, rule_data)
    filename = file.filename or "fixed.docx"
    return StreamingResponse(
        io.BytesIO(fixed_bytes),
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f"attachment; filename=shaper_{filename}"},
    )


@app.post("/batch-fix")
async def batch_fix(files: list[UploadFile] = File(...), rule: str = Form(None)):
    rule_data = _parse_rule(rule)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for upload in files:
            doc_bytes = await upload.read()
            fixed_bytes = apply_fixes(doc_bytes, rule_data)
            name = upload.filename or "fixed.docx"
            archive.writestr(f"shaper_{name}", fixed_bytes)

    buffer.seek(0)
    return StreamingResponse(
        buffer,
        media_type="application/zip",
        headers={"Content-Disposition": "attachment; filename=shaper_batch.zip"},
    )
