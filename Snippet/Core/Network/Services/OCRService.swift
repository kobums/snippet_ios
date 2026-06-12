import Foundation

/// OCR API (문서 §3.10) — 백엔드 프록시 (Google Vision / Naver Clova).
struct OCRService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// POST /ocr/extract — multipart/form-data 텍스트 추출.
    /// - Parameters:
    ///   - imageData: 촬영/선택한 이미지 데이터 (JPEG 권장)
    ///   - filename: 파일명 (확장자 포함)
    ///   - mimeType: 기본 image/jpeg
    ///   - engine: 기본 google
    ///   - regions: 인식 영역 (이미지 픽셀 좌표). 제공 시 영역 내 텍스트만 반환
    func extract(
        imageData: Data,
        filename: String = "image.jpg",
        mimeType: String = "image/jpeg",
        engine: OcrEngine = .google,
        regions: [OcrRegion]? = nil
    ) async throws -> OcrResponse {
        var form = MultipartFormData()
        form.appendFile(name: "image", filename: filename, mimeType: mimeType, data: imageData)
        form.appendField(name: "engine", value: engine.rawValue)
        if let regions, !regions.isEmpty {
            let regionsData = try JSONCoding.encoder.encode(regions)
            if let regionsJSON = String(data: regionsData, encoding: .utf8) {
                form.appendField(name: "regions", value: regionsJSON)
            }
        }
        return try await client.request(
            Endpoint(.post, "/ocr/extract", body: form.finalize(), contentType: form.contentType)
        )
    }
}
