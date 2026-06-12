import Foundation

/// 독서 세션 (ReadingSessionDto, 문서 §3.7).
struct ReadingSessionDto: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let userBookId: Int
    let bookId: Int
    let bookTitle: String
    let bookAuthor: String
    let bookCoverUrl: String
    let durationSeconds: Int
    let startPage: Int
    let endPage: Int
    let pagesRead: Int
    let secondsPerPage: Double
    let sessionDate: String   // "yyyy-MM-dd"
    let createDate: String    // LocalDateTime.toString()

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userBookId = try c.decode(Int.self, forKey: .userBookId)
        bookId = try c.decodeIfPresent(Int.self, forKey: .bookId) ?? 0
        bookTitle = try c.decodeIfPresent(String.self, forKey: .bookTitle) ?? ""
        bookAuthor = try c.decodeIfPresent(String.self, forKey: .bookAuthor) ?? ""
        bookCoverUrl = try c.decodeIfPresent(String.self, forKey: .bookCoverUrl) ?? ""
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
        startPage = try c.decodeIfPresent(Int.self, forKey: .startPage) ?? 0
        endPage = try c.decodeIfPresent(Int.self, forKey: .endPage) ?? 0
        pagesRead = try c.decodeIfPresent(Int.self, forKey: .pagesRead) ?? 0
        secondsPerPage = try c.decodeIfPresent(Double.self, forKey: .secondsPerPage) ?? 0
        sessionDate = try c.decodeIfPresent(String.self, forKey: .sessionDate) ?? ""
        createDate = try c.decodeIfPresent(String.self, forKey: .createDate) ?? ""
    }
}

/// POST /readingsessions 요청 바디. 응답은 bare Long(id).
struct ReadingSessionAddRequest: Encodable, Sendable {
    let userBookId: Int
    let durationSeconds: Int
    let startPage: Int
    let endPage: Int
    let sessionDate: String   // "yyyy-MM-dd"
}

/// GET /readingsessions/stats 응답.
struct ReadingSessionStatsDto: Codable, Equatable, Sendable {
    let totalSessions: Int
    let totalSeconds: Int
    let totalPagesRead: Int
    let avgSecondsPerPage: Double

    static let empty = ReadingSessionStatsDto(
        totalSessions: 0, totalSeconds: 0, totalPagesRead: 0, avgSecondsPerPage: 0
    )
}

/// GET /readingsessions/streak 응답.
struct StreakDto: Codable, Equatable, Sendable {
    let currentStreak: Int
    let maxStreak: Int
    let lastReadDate: String?   // "yyyy-MM-dd"

    static let empty = StreakDto(currentStreak: 0, maxStreak: 0, lastReadDate: nil)

    init(currentStreak: Int, maxStreak: Int, lastReadDate: String?) {
        self.currentStreak = currentStreak
        self.maxStreak = maxStreak
        self.lastReadDate = lastReadDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        maxStreak = try c.decodeIfPresent(Int.self, forKey: .maxStreak) ?? 0
        lastReadDate = try c.decodeIfPresent(String.self, forKey: .lastReadDate)
    }
}
