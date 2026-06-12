import Foundation

/// POST /ocr/extract 응답. confidence 0~100 (앱은 extractedText만 사용).
struct OcrResponse: Codable, Equatable, Sendable {
    let extractedText: String
    let confidence: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        extractedText = try c.decodeIfPresent(String.self, forKey: .extractedText) ?? ""
        confidence = try c.decodeIfPresent(Int.self, forKey: .confidence) ?? 0
    }
}

/// OCR 인식 영역 (이미지 픽셀 좌표). multipart `regions` 파트에 JSON 배열 문자열로 전송.
struct OcrRegion: Codable, Equatable, Sendable {
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double
}
