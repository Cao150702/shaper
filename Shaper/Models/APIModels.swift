import Foundation

struct AnalysisResponse: Codable {
    var summary: AnalysisSummaryDTO?
    var violations: [ViolationDTO]
}

struct AnalysisSummaryDTO: Codable {
    var violations: Int?
}

struct ViolationDTO: Codable {
    var title: String
    var detail: String
    var severity: String
}

struct ServerTemplateDTO: Codable {
    var name: String
    var body: BodyDTO
    var documentTitle: DocumentTitleDTO?
    var titles: [TitleDTO]
    var page: PageDTO
    var toc: TocDTO

    enum CodingKeys: String, CodingKey {
        case name
        case body
        case documentTitle = "document_title"
        case titles
        case page
        case toc
    }
}

struct BodyDTO: Codable {
    var font: String
    var size: Int
    var lineSpacing: Double
    var firstLineIndentEm: Int

    enum CodingKeys: String, CodingKey {
        case font
        case size
        case lineSpacing = "line_spacing"
        case firstLineIndentEm = "first_line_indent_em"
    }
}

struct DocumentTitleDTO: Codable {
    var font: String
    var size: Int
    var bold: Bool
    var alignment: String
}

struct TitleDTO: Codable {
    var level: Int
    var font: String
    var size: Int
    var bold: Bool
    var alignment: String
}

struct PageDTO: Codable {
    var marginCm: Double
    var header: Bool
    var footer: Bool
    var pageNumber: String

    enum CodingKeys: String, CodingKey {
        case marginCm = "margin_cm"
        case header
        case footer
        case pageNumber = "page_number"
    }
}

struct TocDTO: Codable {
    var enable: Bool
}
