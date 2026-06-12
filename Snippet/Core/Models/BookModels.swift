import Foundation

/// GET /books/search 응답 항목 (알라딘 검색 프록시).
struct BookSearchDto: Codable, Equatable, Sendable {
    let title: String
    let author: String
    let publisher: String
    let pubDate: String
    let isbn: String
    let coverUrl: String
    let totalPage: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        publisher = try c.decodeIfPresent(String.self, forKey: .publisher) ?? ""
        pubDate = try c.decodeIfPresent(String.self, forKey: .pubDate) ?? ""
        isbn = try c.decodeIfPresent(String.self, forKey: .isbn) ?? ""
        coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl) ?? ""
        totalPage = try c.decodeIfPresent(Int.self, forKey: .totalPage)
    }
}

/// GET /books/popular 응답 항목 (국립중앙도서관 인기 대출 도서).
/// 모든 필드 null-safe 폴백 (숫자 0, 문자열 "") — 문서 §3.6.
struct PopularBookDto: Codable, Equatable, Sendable {
    let rank: Int
    let title: String
    let author: String
    let publisher: String
    let isbn13: String
    let kdc: String
    let kdcName: String
    let loanCount: Int
    let coverUrl: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        publisher = try c.decodeIfPresent(String.self, forKey: .publisher) ?? ""
        isbn13 = try c.decodeIfPresent(String.self, forKey: .isbn13) ?? ""
        kdc = try c.decodeIfPresent(String.self, forKey: .kdc) ?? ""
        kdcName = try c.decodeIfPresent(String.self, forKey: .kdcName) ?? ""
        loanCount = try c.decodeIfPresent(Int.self, forKey: .loanCount) ?? 0
        coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl) ?? ""
    }
}

/// GET /books/popular 쿼리 파라미터 (모두 optional — 빈 값은 미전송).
struct PopularBooksQuery: Sendable {
    var startDt: String?
    var endDt: String?
    var kdc: String?
    var dtlKdc: String?
    var age: String?
    var gender: String?
    var region: String?
    var dtlRegion: String?
    var pageNo: Int = 1
    var pageSize: Int = 20

    init() {}
}

/// GET /books/recommend 응답 항목.
struct BookRecommendDto: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
    let coverUrl: String
    let category: String?
    let reason: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category)
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }
}
