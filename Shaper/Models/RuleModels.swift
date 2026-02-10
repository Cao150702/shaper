import Foundation

struct RuleTemplate: Identifiable, Codable, Hashable {
    enum Source: String, Codable {
        case builtin
        case custom
        case ai
    }

    let id: UUID
    var name: String
    var summary: String
    var source: Source
    var body: BodyRule
    var documentTitle: DocumentTitleRule?
    var titles: [TitleRule]
    var page: PageRule
    var tocEnabled: Bool
    var updatedAt: Date

    static func defaultTemplates() -> [RuleTemplate] {
        let commonBody = BodyRule(font: "宋体", size: 12, lineSpacing: 1.5, firstLineIndentEm: 2)
        let titleRule = DocumentTitleRule(font: "黑体", size: 18, bold: true, alignment: .center)
        return [
            RuleTemplate(
                id: UUID(),
                name: "学校模板",
                summary: "常见课程作业排版规范",
                source: .builtin,
                body: commonBody,
                documentTitle: titleRule,
                titles: [
                    TitleRule(level: 1, font: "黑体", size: 16, bold: true, alignment: .center),
                    TitleRule(level: 2, font: "黑体", size: 14, bold: true, alignment: .leading),
                    TitleRule(level: 3, font: "黑体", size: 12, bold: true, alignment: .leading)
                ],
                page: PageRule(marginCm: 2.5, headerEnabled: true, footerEnabled: true, pageNumber: .bottomCenter),
                tocEnabled: true,
                updatedAt: Date()
            ),
            RuleTemplate(
                id: UUID(),
                name: "通用论文模板",
                summary: "适合大多数论文提交的通用格式",
                source: .builtin,
                body: commonBody,
                documentTitle: titleRule,
                titles: [
                    TitleRule(level: 1, font: "黑体", size: 16, bold: true, alignment: .center),
                    TitleRule(level: 2, font: "黑体", size: 14, bold: true, alignment: .leading),
                    TitleRule(level: 3, font: "黑体", size: 12, bold: true, alignment: .leading)
                ],
                page: PageRule(marginCm: 2.5, headerEnabled: true, footerEnabled: true, pageNumber: .bottomCenter),
                tocEnabled: true,
                updatedAt: Date()
            )
        ]
    }
}

struct BodyRule: Codable, Hashable {
    var font: String
    var size: Int
    var lineSpacing: Double
    var firstLineIndentEm: Int
}

struct DocumentTitleRule: Codable, Hashable {
    var font: String
    var size: Int
    var bold: Bool
    var alignment: TextAlignmentRule
}

struct TitleRule: Codable, Hashable, Identifiable {
    let id: UUID
    var level: Int
    var font: String
    var size: Int
    var bold: Bool
    var alignment: TextAlignmentRule

    init(level: Int, font: String, size: Int, bold: Bool, alignment: TextAlignmentRule) {
        self.id = UUID()
        self.level = level
        self.font = font
        self.size = size
        self.bold = bold
        self.alignment = alignment
    }
}

struct PageRule: Codable, Hashable {
    var marginCm: Double
    var headerEnabled: Bool
    var footerEnabled: Bool
    var pageNumber: PageNumberPosition
}

enum TextAlignmentRule: String, Codable {
    case leading
    case center
}

enum PageNumberPosition: String, Codable {
    case bottomCenter
    case bottomRight
}

struct Violation: Identifiable, Hashable {
    enum Severity: String {
        case high
        case medium
        case low
    }

    let id: UUID
    var title: String
    var detail: String
    var severity: Severity
}

struct DocumentItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var sizeKB: Int
    var url: URL
}

struct AnalysisSummary {
    var documentCount: Int
    var violationCount: Int
}

struct FixSummary {
    var documentCount: Int
    var fixedItems: Int
    var generatedTOC: Bool
}
