import Foundation

/// 독서 기록 (RecordDto, 문서 §3.5).
/// bookAuthor / bookCoverUrl 은 구 데이터에서 null일 수 있어 "" 폴백.
struct RecordDto: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let bookId: Int
    let bookTitle: String
    let bookAuthor: String
    let bookCoverUrl: String
    let type: RecordType
    let text: String
    let tag: String?
    let relatedPage: Int?
    let createDate: String   // ISO LocalDateTime

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        bookId = try c.decode(Int.self, forKey: .bookId)
        bookTitle = try c.decodeIfPresent(String.self, forKey: .bookTitle) ?? ""
        bookAuthor = try c.decodeIfPresent(String.self, forKey: .bookAuthor) ?? ""
        bookCoverUrl = try c.decodeIfPresent(String.self, forKey: .bookCoverUrl) ?? ""
        type = try c.decodeIfPresent(RecordType.self, forKey: .type) ?? .snippet
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        relatedPage = try c.decodeIfPresent(Int.self, forKey: .relatedPage)
        createDate = try c.decodeIfPresent(String.self, forKey: .createDate) ?? ""
    }
}

/// POST /records 요청 바디. 응답은 bare Long(recordId) (문서 §3.5 경고).
struct RecordAddRequest: Encodable, Sendable {
    let bookId: Int
    let type: RecordType
    let text: String
    var tag: String?
    var relatedPage: Int?
}

/// PATCH /records/{id} 요청 바디 — nil 키는 생략.
struct RecordUpdateRequest: Encodable, Sendable {
    var type: RecordType?
    var text: String?
    var tag: String?
    var relatedPage: Int?
}
