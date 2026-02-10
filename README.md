# Shaper

面向高校学生的 DOCX 论文排版自动化工具（iOS + 本地服务）。

## 功能
- DOCX 导入与预览（QuickLook）
- 违规项检测与解释
- 一键修复（字体、字号、行距、首行缩进、标题层级）
- 自动生成目录、页码、页边距
- 批量修复（输出 zip）
- 模板同步（从本地服务拉取高校模板）

## 架构
- iOS App（SwiftUI）：交互与预览
- 本地服务（FastAPI）：DOCX 解析与修复

## 运行环境
- macOS + Xcode 16+
- Python 3.12+

## 启动本地服务
```bash
cd /Users/cao/Shaper/Shaper/server
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

服务地址：`http://127.0.0.1:8000`

## 启动 iOS App
1. 用 Xcode 打开 `Shaper.xcodeproj`
2. 运行 App
3. 进入“服务器设置”，填写服务地址
   - 模拟器：`http://127.0.0.1:8000`
   - 真机：填你电脑的局域网 IP（例如 `http://192.168.1.10:8000`）

## 使用流程
1. 选择模板或同步模板
2. 导入 `.docx`
3. 分析 → 预览 → 一键修复
4. 另存为输出文件

> 目录与页码是 Word 字段，打开文档后请更新域（F9 或右键更新域）。

## 目录结构
```
Shaper/
  Shaper/                # iOS App
  server/                # 本地服务（FastAPI）
```

## API
- `GET /templates` 拉取模板
- `POST /analyze` 分析违规项
- `POST /fix` 单文件修复
- `POST /batch-fix` 批量修复
