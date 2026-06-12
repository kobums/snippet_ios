import Foundation

/// multipart/form-data 바디 빌더 (OCR 업로드용, 문서 §3.10).
struct MultipartFormData {
    let boundary: String
    private var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// 텍스트 필드 추가.
    mutating func appendField(name: String, value: String) {
        body.append(string: "--\(boundary)\r\n")
        body.append(string: "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append(string: "\(value)\r\n")
    }

    /// 파일 파트 추가.
    mutating func appendFile(name: String, filename: String, mimeType: String, data: Data) {
        body.append(string: "--\(boundary)\r\n")
        body.append(string: "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.append(string: "Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append(string: "\r\n")
    }

    /// 종료 boundary를 붙인 최종 바디.
    func finalize() -> Data {
        var result = body
        result.append(string: "--\(boundary)--\r\n")
        return result
    }
}

private extension Data {
    mutating func append(string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
