import Foundation

/// 건의 응답 (POST /suggestions, GET /suggestions/mine).
struct SuggestionDto: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let category: String
    let title: String?
    let content: String
    let status: String
    let createDate: String    // ISO LocalDateTime
    let answer: String?       // 관리자 답변 (미답변 시 null)
    let answerDate: String?   // ISO LocalDateTime, null 가능

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        createDate = try c.decodeIfPresent(String.self, forKey: .createDate) ?? ""
        answer = try c.decodeIfPresent(String.self, forKey: .answer)
        answerDate = try c.decodeIfPresent(String.self, forKey: .answerDate)
    }
}

/// POST /suggestions 요청 바디.
/// title이 빈 문자열이면 키 자체를 생략한다 (문서 §3.9).
struct SuggestionRequest: Encodable, Sendable {
    let category: SuggestionCategory
    let title: String?
    let content: String

    private enum CodingKeys: String, CodingKey {
        case category, title, content
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(category, forKey: .category)
        if let title, !title.isEmpty {
            try c.encode(title, forKey: .title)
        }
        try c.encode(content, forKey: .content)
    }
}
