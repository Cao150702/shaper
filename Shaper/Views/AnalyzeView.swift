import SwiftUI

struct AnalyzeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showFixResult = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                previewSection
                summarySection
                violationsSection
                if let message = appState.errorMessage {
                    Text(message)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.red)
                }
                fixButton
                NavigationLink(destination: FixResultView(), isActive: $showFixResult) {
                    EmptyView()
                }
            }
            .padding(20)
        }
        .background(Color(white: 0.96))
        .navigationTitle("预览")
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文档预览")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            if let url = appState.documents.first?.url {
                QuickLookPreview(url: url)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.05))
                    )
                    .onAppear {
                        _ = url.startAccessingSecurityScopedResource()
                    }
                    .onDisappear {
                        url.stopAccessingSecurityScopedResource()
                    }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(height: 220)
                    .overlay(
                        Text("暂无可预览的文档")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = appState.analysisSummary {
                Text("已检查 \(summary.documentCount) 个文件")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("发现 \(summary.violationCount) 个违规项")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var violationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("违规项")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            ForEach(appState.violations) { violation in
                ViolationRow(violation: violation)
            }
        }
    }

    private var fixButton: some View {
        Button {
            Task {
                await appState.fix()
                if appState.errorMessage == nil {
                    showFixResult = true
                }
            }
        } label: {
            HStack {
                Spacer()
                Text(appState.isFixing ? "修复中..." : "一键修复")
                Spacer()
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ViolationRow: View {
    let violation: Violation

    private var severityColor: Color {
        switch violation.severity {
        case .high:
            return Color.red.opacity(0.7)
        case .medium:
            return Color.orange.opacity(0.7)
        case .low:
            return Color.gray.opacity(0.6)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                Text(violation.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Text(violation.detail)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        AnalyzeView()
            .environmentObject(AppState())
    }
}
