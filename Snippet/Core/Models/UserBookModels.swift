import Foundation

/// 사용자 서재 도서 (UserBookDto, 문서 §3.3).
/// 날짜 필드는 전부 String 보관 — 표시 시점에 `APIDate`로 파싱한다.
struct UserBookDto: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let bookId: Int
    let title: String
    let author: String
    let coverUrl: String
    let type: BookType
    let status: BookStatus
    let readPage: Int
    let totalPage: Int
    let createDate: String      // ISO LocalDateTime
    let startDate: String?
    let endDate: String?
    let rating: Int?            // 1~5
    let returnDate: String?     // 대출 반납 예정일

    /// 진행률 0.0~1.0 (totalPage == 0 이면 0).
    var progress: Double {
        guard totalPage > 0 else { return 0 }
        return min(max(Double(readPage) / Double(totalPage), 0), 1)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        bookId = try c.decode(Int.self, forKey: .bookId)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl) ?? ""
        type = try c.decode(BookType.self, forKey: .type)
        status = try c.decode(BookStatus.self, forKey: .status)
        readPage = try c.decodeIfPresent(Int.self, forKey: .readPage) ?? 0
        totalPage = try c.decodeIfPresent(Int.self, forKey: .totalPage) ?? 0
        createDate = try c.decodeIfPresent(String.self, forKey: .createDate) ?? ""
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        returnDate = try c.decodeIfPresent(String.self, forKey: .returnDate)
    }
}

/// POST /userbooks 요청 바디 (LibraryAddRequestDto).
/// 응답은 bare Long(userBookId) — 객체 디코딩 금지 (문서 §3.3 경고).
struct LibraryAddRequest: Encodable, Sendable {
    let title: String
    let author: String
    let publisher: String
    let pubDate: String
    let isbn: String
    let coverUrl: String
    let totalPage: Int
    let type: BookType
    let status: BookStatus
    var readPage: Int = 0
    let startDate: String   // ISO-8601, 미선택 시 now
    let endDate: String
    let createDate: String
}

/// PATCH /userbooks/{id} 요청 바디 — 전부 optional, nil 키는 인코딩에서 생략된다.
struct UserBookUpdateRequest: Encodable, Sendable {
    var type: BookType?
    var status: BookStatus?
    var readPage: Int?
    var startDate: String?
    var endDate: String?
    var rating: Int?
    var returnDate: String?
}
