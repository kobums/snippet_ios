import Foundation

/// 독서 통계 API (`/userbooks/stats/*`, 문서 §3.4) — 인증 필요.
struct StatsService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /userbooks/stats/monthly?year= (기본 올해)
    func monthly(year: Int? = nil) async throws -> [MonthlyStatsDto] {
        try await client.request(
            Endpoint(.get, "/userbooks/stats/monthly", queryItems: Self.yearQuery(year))
        )
    }

    /// GET /userbooks/stats/yearly
    func yearly() async throws -> [YearlyStatsDto] {
        try await client.request(Endpoint(.get, "/userbooks/stats/yearly"))
    }

    /// GET /userbooks/stats/category?year=
    func category(year: Int? = nil) async throws -> [CategoryStatsDto] {
        try await client.request(
            Endpoint(.get, "/userbooks/stats/category", queryItems: Self.yearQuery(year))
        )
    }

    /// GET /userbooks/stats/insights?year=
    func insights(year: Int? = nil) async throws -> ReadingInsightsDto {
        try await client.request(
            Endpoint(.get, "/userbooks/stats/insights", queryItems: Self.yearQuery(year))
        )
    }

    private static func yearQuery(_ year: Int?) -> [URLQueryItem] {
        guard let year else { return [] }
        return [URLQueryItem(name: "year", value: String(year))]
    }
}
