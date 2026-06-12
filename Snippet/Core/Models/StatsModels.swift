import Foundation

/// GET /userbooks/stats/monthly 응답 항목.
struct MonthlyStatsDto: Codable, Equatable, Sendable {
    let month: Int
    let completedCount: Int
    let totalPages: Int
    let categoryCount: [String: Int]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decode(Int.self, forKey: .month)
        completedCount = try c.decodeIfPresent(Int.self, forKey: .completedCount) ?? 0
        totalPages = try c.decodeIfPresent(Int.self, forKey: .totalPages) ?? 0
        categoryCount = try c.decodeIfPresent([String: Int].self, forKey: .categoryCount) ?? [:]
    }
}

/// GET /userbooks/stats/yearly 응답 항목.
struct YearlyStatsDto: Codable, Equatable, Sendable {
    let year: Int
    let completedCount: Int
    let totalPages: Int
}

/// GET /userbooks/stats/category 응답 항목.
struct CategoryStatsDto: Codable, Equatable, Sendable {
    let category: String
    let totalCount: Int
    let completedCount: Int
    let completionRate: Double
}

/// GET /userbooks/stats/insights 응답.
struct ReadingInsightsDto: Codable, Equatable, Sendable {
    let averageReadingDays: Double
    let topCategory: String
    let longestReadingDays: Int
    let longestBook: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        averageReadingDays = try c.decodeIfPresent(Double.self, forKey: .averageReadingDays) ?? 0
        topCategory = try c.decodeIfPresent(String.self, forKey: .topCategory) ?? ""
        longestReadingDays = try c.decodeIfPresent(Int.self, forKey: .longestReadingDays) ?? 0
        longestBook = try c.decodeIfPresent(String.self, forKey: .longestBook) ?? ""
    }
}
