import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var templates: [RuleTemplate] = RuleTemplate.defaultTemplates()
    @Published var selectedTemplateId: UUID?
    @Published var documents: [DocumentItem] = []
    @Published var violations: [Violation] = []
    @Published var analysisSummary: AnalysisSummary?
    @Published var fixSummary: FixSummary?
    @Published var isAnalyzing = false
    @Published var isFixing = false
    @Published var errorMessage: String?
    @Published var exportData: Data?
    @Published var exportFileName: String = "排版修复.docx"
    @Published var serverAddress: String = "http://127.0.0.1:8000"

    init() {
        selectedTemplateId = templates.first?.id
    }

    var selectedTemplate: RuleTemplate? {
        templates.first { $0.id == selectedTemplateId }
    }

    func addDocuments(urls: [URL]) {
        let newItems = urls.map { url in
            DocumentItem(id: UUID(), name: url.lastPathComponent, sizeKB: Int.random(in: 80...320), url: url)
        }
        documents.append(contentsOf: newItems)
    }

    func syncTemplates() async {
        isAnalyzing = true
        errorMessage = nil
        do {
            let client = APIClient(baseURL: serverURL)
            let templatesDTO = try await client.fetchTemplates()
            let mapped = templatesDTO.map { dto -> RuleTemplate in
                let alignment: (String) -> TextAlignmentRule = { value in
                    value == "center" ? .center : .leading
                }
                let titles = dto.titles.map {
                    TitleRule(
                        level: $0.level,
                        font: $0.font,
                        size: $0.size,
                        bold: $0.bold,
                        alignment: alignment($0.alignment)
                    )
                }
                let documentTitle = dto.documentTitle.map {
                    DocumentTitleRule(
                        font: $0.font,
                        size: $0.size,
                        bold: $0.bold,
                        alignment: alignment($0.alignment)
                    )
                }
                let pageNumber: PageNumberPosition = dto.page.pageNumber == "bottom_right" ? .bottomRight : .bottomCenter

                return RuleTemplate(
                    id: UUID(),
                    name: dto.name,
                    summary: "来自服务器的高校模板",
                    source: .builtin,
                    body: BodyRule(
                        font: dto.body.font,
                        size: dto.body.size,
                        lineSpacing: dto.body.lineSpacing,
                        firstLineIndentEm: dto.body.firstLineIndentEm
                    ),
                    documentTitle: documentTitle,
                    titles: titles,
                    page: PageRule(
                        marginCm: dto.page.marginCm,
                        headerEnabled: dto.page.header,
                        footerEnabled: dto.page.footer,
                        pageNumber: pageNumber
                    ),
                    tocEnabled: dto.toc.enable,
                    updatedAt: Date()
                )
            }
            templates = mapped.isEmpty ? RuleTemplate.defaultTemplates() : mapped
            selectedTemplateId = templates.first?.id
        } catch {
            errorMessage = "同步模板失败：\(error.localizedDescription)"
        }
        isAnalyzing = false
    }

    func analyze() async {
        guard let first = documents.first else { return }
        isAnalyzing = true
        errorMessage = nil

        do {
            let client = APIClient(baseURL: serverURL)
            let json = try ruleJSON()
            let data = try await client.analyze(fileURL: first.url, ruleJSON: json)
            let response = try JSONDecoder().decode(AnalysisResponse.self, from: data)
            let mapped = response.violations.map { dto in
                Violation(
                    id: UUID(),
                    title: dto.title,
                    detail: dto.detail,
                    severity: Violation.Severity(rawValue: dto.severity) ?? .low
                )
            }
            violations = mapped
            analysisSummary = AnalysisSummary(documentCount: documents.count, violationCount: mapped.count)
        } catch {
            errorMessage = "分析失败：\(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    func fix() async {
        guard !documents.isEmpty else { return }
        isFixing = true
        errorMessage = nil

        do {
            let client = APIClient(baseURL: serverURL)
            let json = try ruleJSON()
            if documents.count == 1, let first = documents.first {
                exportData = try await client.fix(fileURL: first.url, ruleJSON: json)
                exportFileName = "排版修复_\(first.name)"
            } else {
                let urls = documents.map { $0.url }
                exportData = try await client.fixBatch(fileURLs: urls, ruleJSON: json)
                exportFileName = "排版修复_批量.zip"
            }
            fixSummary = FixSummary(documentCount: documents.count, fixedItems: violations.count, generatedTOC: true)
        } catch {
            errorMessage = "修复失败：\(error.localizedDescription)"
        }

        isFixing = false
    }

    func addTemplate(_ template: RuleTemplate) {
        templates.insert(template, at: 0)
        selectedTemplateId = template.id
    }

    private var serverURL: URL {
        URL(string: serverAddress) ?? URL(string: "http://127.0.0.1:8000")!
    }

    private func ruleJSON() throws -> String {
        guard let template = selectedTemplate else { return "{}" }
        let titles = template.titles.map {
            [
                "level": $0.level,
                "font": $0.font,
                "size": $0.size,
                "bold": $0.bold,
                "alignment": $0.alignment.rawValue
            ]
        }
        let documentTitle = template.documentTitle.map {
            [
                "font": $0.font,
                "size": $0.size,
                "bold": $0.bold,
                "alignment": $0.alignment.rawValue
            ]
        }
        let payload: [String: Any] = [
            "body": [
                "font": template.body.font,
                "size": template.body.size,
                "line_spacing": template.body.lineSpacing,
                "first_line_indent_em": template.body.firstLineIndentEm
            ],
            "document_title": documentTitle ?? [
                "font": "黑体",
                "size": 18,
                "bold": true,
                "alignment": "center"
            ],
            "titles": titles,
            "page": [
                "margin_cm": template.page.marginCm,
                "header": template.page.headerEnabled,
                "footer": template.page.footerEnabled,
                "page_number": template.page.pageNumber.rawValue == "bottomCenter" ? "bottom_center" : "bottom_right"
            ],
            "toc": ["enable": template.tocEnabled]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
