import Foundation

/// 독서 목표 (GET/PUT /readinggoals).
/// 조회 실패 시 `empty(year:)` 폴백 (문서 §3.8 — 에러 미노출).
struct ReadingGoalDto: Codable, Equatable, Sendable {
    let year: Int
    let targetBooks: Int
    let completedBooks: Int

    /// 진행률 0.0~1.0 (targetBooks == 0 이면 0).
    var progress: Double {
        guard targetBooks > 0 else { return 0 }
        return min(max(Double(completedBooks) / Double(targetBooks), 0), 1)
    }

    static func empty(year: Int = Calendar.current.component(.year, from: Date())) -> ReadingGoalDto {
        ReadingGoalDto(year: year, targetBooks: 0, completedBooks: 0)
    }
}

/// PUT /readinggoals 요청 바디.
struct ReadingGoalUpdateRequest: Encodable, Sendable {
    let year: Int
    let targetBooks: Int
}
