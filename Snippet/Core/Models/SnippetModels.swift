import Foundation

/// 스와이프 카드 한 장 (GET /snippets/cards 의 cards 항목).
struct SnippetCard: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let tag: String?
    let bookTitle: String?
}

/// GET /snippets/cards 응답.
/// `remainingToday == -1` 은 비로그인(무제한), `0` 은 일일 제한 도달.
struct SnippetCardsResponse: Codable, Sendable {
    let cards: [SnippetCard]
    let remainingToday: Int
}

/// 아카이브 항목 (GET /snippets/archive).
/// 책 메타 필드는 서버가 null을 줄 수 있어 "" 폴백 (문서 §3.2).
struct SnippetArchive: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    let tag: String?
    let bookTitle: String
    let bookAuthor: String
    let coverUrl: String
    let affiliateUrl: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        bookTitle = try c.decodeIfPresent(String.self, forKey: .bookTitle) ?? ""
        bookAuthor = try c.decodeIfPresent(String.self, forKey: .bookAuthor) ?? ""
        coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl) ?? ""
        affiliateUrl = try c.decodeIfPresent(String.self, forKey: .affiliateUrl) ?? ""
    }
}
