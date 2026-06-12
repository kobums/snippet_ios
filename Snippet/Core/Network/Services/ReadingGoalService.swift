import Foundation

/// 독서 목표 API (문서 §3.8) — 인증 필요.
struct ReadingGoalService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /readinggoals?year= (기본 올해). 호출부는 실패 시 `.empty(year:)` 폴백 권장.
    func fetch(year: Int? = nil) async throws -> ReadingGoalDto {
        var queryItems: [URLQueryItem] = []
        if let year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }
        return try await client.request(Endpoint(.get, "/readinggoals", queryItems: queryItems))
    }

    /// PUT /readinggoals — 목표 설정 (생략 시 서버 기본: 올해, 12권).
    @discardableResult
    func update(year: Int, targetBooks: Int) async throws -> ReadingGoalDto {
        try await client.request(
            try Endpoint(.put, "/readinggoals", json: ReadingGoalUpdateRequest(year: year, targetBooks: targetBooks))
        )
    }
}
