import Foundation

/// 독서 로그 API (`/readinglogs/*`) — 인증 필요.
struct ReadingLogService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /readinglogs/daily?year=&month= — 일별 읽은 페이지 (읽은 날만 반환).
    func daily(year: Int, month: Int) async throws -> [DailyPagesDto] {
        try await client.request(
            Endpoint(.get, "/readinglogs/daily", queryItems: [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month)),
            ])
        )
    }
}
