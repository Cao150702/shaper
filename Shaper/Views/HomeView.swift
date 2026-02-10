import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPicker = false
    @State private var showRuleInput = false
    @State private var showAnalyze = false
    @State private var showServer = false

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    templateSection
                    serverSection
                    importSection
                    documentList
                    analyzeButton
                    NavigationLink(destination: AnalyzeView(), isActive: $showAnalyze) {
                        EmptyView()
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("排版助手")
        .sheet(isPresented: $showPicker) {
            DocumentPicker { urls in
                appState.addDocuments(urls: urls)
            }
        }
        .sheet(isPresented: $showRuleInput) {
            RuleInputView { template in
                appState.addTemplate(template)
            }
        }
        .sheet(isPresented: $showServer) {
            ServerSettingView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DOCX 自动排版")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("导入、检查违规项，一键修复。")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("模板")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Button("同步模板") {
                    Task {
                        await appState.syncTemplates()
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                Button("新建 / 编辑") {
                    showRuleInput = true
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            }

            Menu {
                ForEach(appState.templates) { template in
                    Button(template.name) {
                        appState.selectedTemplateId = template.id
                    }
                }
            } label: {
                HStack {
                    Text(appState.selectedTemplate?.name ?? "请选择")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding(12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let template = appState.selectedTemplate {
                TemplateCard(template: template)
            }
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文档")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Button {
                showPicker = true
            } label: {
                HStack {
                    Image(systemName: "tray.and.arrow.down")
                    Text("导入 .docx")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("服务器")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Button("设置") {
                    showServer = true
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            Text(appState.serverAddress)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var documentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(appState.documents) { item in
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("~\(item.sizeKB) KB")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if appState.documents.isEmpty {
                Text("还没有文档，请先导入 .docx。")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if let message = appState.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
    }

    private var analyzeButton: some View {
        Button {
            Task {
                await appState.analyze()
                if appState.errorMessage == nil {
                    showAnalyze = true
                }
            }
        } label: {
            HStack {
                Spacer()
                Text(appState.isAnalyzing ? "分析中..." : "分析与预览")
                Spacer()
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .background(appState.documents.isEmpty ? Color.gray.opacity(0.5) : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(appState.documents.isEmpty)
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [Color(white: 0.97), Color(white: 0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct TemplateCard: View {
    let template: RuleTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(template.summary)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
            if let titleRule = template.documentTitle {
                Text("论文标题: \(titleRule.font) \(titleRule.size)pt")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            Text("正文: \(template.body.font) \(template.body.size)pt · \(template.body.lineSpacing)x")
                .font(.system(size: 12, weight: .regular, design: .rounded))
            Text("一级标题: \(template.titles.first?.font ?? "黑体") \(template.titles.first?.size ?? 16)pt")
                .font(.system(size: 12, weight: .regular, design: .rounded))
            Text("目录: \(template.tocEnabled ? "开启" : "关闭") · 页边距: \(template.page.marginCm, specifier: "%.1f")cm")
                .font(.system(size: 12, weight: .regular, design: .rounded))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState())
    }
}
