import SwiftUI
import UniformTypeIdentifiers

struct FixResultView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showExporter = false
    @State private var exportDocument = ExportDocument(data: Data())

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summarySection
            exportSection
            Spacer()
        }
        .padding(20)
        .background(Color(white: 0.96))
        .navigationTitle("保存结果")
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .data,
            defaultFilename: appState.exportFileName
        ) { _ in }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("修复摘要")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            if let summary = appState.fixSummary {
                Text("已修复 \(summary.documentCount) 个文件")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("修复 \(summary.fixedItems) 项 · 目录\(summary.generatedTOC ? "已生成" : "未生成")")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未修复。")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Button {
                if let data = appState.exportData {
                    exportDocument = ExportDocument(data: data)
                    showExporter = true
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("另存为")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(appState.exportData == nil ? Color.gray.opacity(0.5) : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(appState.exportData == nil)
        }
    }
}

#Preview {
    NavigationStack {
        FixResultView()
            .environmentObject(AppState())
    }
}
