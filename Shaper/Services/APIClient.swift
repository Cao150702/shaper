import Foundation

struct APIClient {
    var baseURL: URL

    func fetchTemplates() async throws -> [ServerTemplateDTO] {
        let request = URLRequest(url: baseURL.appendingPathComponent("templates"))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode([ServerTemplateDTO].self, from: data)
    }

    func analyze(fileURL: URL, ruleJSON: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("analyze"))
        request.httpMethod = "POST"
        let (body, boundary) = try makeMultipartBody(fileURLs: [fileURL], ruleJSON: ruleJSON, fieldName: "file")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return data
    }

    func fix(fileURL: URL, ruleJSON: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("fix"))
        request.httpMethod = "POST"
        let (body, boundary) = try makeMultipartBody(fileURLs: [fileURL], ruleJSON: ruleJSON, fieldName: "file")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return data
    }

    func fixBatch(fileURLs: [URL], ruleJSON: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("batch-fix"))
        request.httpMethod = "POST"
        let (body, boundary) = try makeMultipartBody(fileURLs: fileURLs, ruleJSON: ruleJSON, fieldName: "files")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return data
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "APIClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务返回错误 \(http.statusCode)"])
        }
    }

    private func makeMultipartBody(fileURLs: [URL], ruleJSON: String, fieldName: String) throws -> (Data, String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"rule\"\r\n\r\n")
        append(ruleJSON)
        append("\r\n")

        for fileURL in fileURLs {
            let filename = fileURL.lastPathComponent
            let access = fileURL.startAccessingSecurityScopedResource()
            defer {
                if access {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: fileURL)
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
            append("Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document\r\n\r\n")
            body.append(data)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        return (body, boundary)
    }
}
