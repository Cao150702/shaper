import SwiftUI

struct RuleInputView: View {
    enum Mode: String, CaseIterable {
        case form = "表单"
        case ai = "智能"
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .form

    @State private var name = "自定义模板"
    @State private var font = "宋体"
    @State private var size = "12"
    @State private var lineSpacing = "1.5"
    @State private var indent = "2"
    @State private var titleFont = "黑体"
    @State private var titleSize = "18"
    @State private var tocEnabled = true
    @State private var aiPrompt = ""

    var onSave: (RuleTemplate) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .form {
                    formSection
                } else {
                    aiSection
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("规则编辑")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(buildTemplate())
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("模板名称", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("正文字体", text: $font)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField("字号", text: $size)
                    .textFieldStyle(.roundedBorder)
                TextField("行距", text: $lineSpacing)
                    .textFieldStyle(.roundedBorder)
                TextField("首行缩进 (em)", text: $indent)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("标题字体", text: $titleFont)
                .textFieldStyle(.roundedBorder)

            TextField("论文标题字号", text: $titleSize)
                .textFieldStyle(.roundedBorder)

            Toggle("开启目录", isOn: $tocEnabled)
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("用自然语言描述你的排版规则")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            TextEditor(text: $aiPrompt)
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3))
                )

            Button("生成规则") {
                name = "AI 模板"
                font = "宋体"
                size = "12"
                lineSpacing = "1.5"
                indent = "2"
                titleFont = "黑体"
                titleSize = "18"
                tocEnabled = true
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
    }

    private func buildTemplate() -> RuleTemplate {
        let body = BodyRule(
            font: font,
            size: Int(size) ?? 12,
            lineSpacing: Double(lineSpacing) ?? 1.5,
            firstLineIndentEm: Int(indent) ?? 2
        )
        return RuleTemplate(
            id: UUID(),
            name: name,
            summary: "用户自定义规则",
            source: mode == .ai ? .ai : .custom,
            body: body,
            documentTitle: DocumentTitleRule(
                font: titleFont,
                size: Int(titleSize) ?? 18,
                bold: true,
                alignment: .center
            ),
            titles: [
                TitleRule(level: 1, font: titleFont, size: 16, bold: true, alignment: .center),
                TitleRule(level: 2, font: titleFont, size: 14, bold: true, alignment: .leading),
                TitleRule(level: 3, font: titleFont, size: 12, bold: true, alignment: .leading)
            ],
            page: PageRule(marginCm: 2.5, headerEnabled: true, footerEnabled: true, pageNumber: .bottomCenter),
            tocEnabled: tocEnabled,
            updatedAt: Date()
        )
    }
}

#Preview {
    RuleInputView { _ in }
}
