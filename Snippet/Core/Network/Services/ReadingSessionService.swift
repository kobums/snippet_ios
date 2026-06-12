import Foundation

/// 독서 세션 API (문서 §3.7) — 인증 필요.
struct ReadingSessionService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /readingsessions — 전체 세션 (최신순).
    func fetchAll() async throws -> [ReadingSessionDto] {
        try await client.request(Endpoint(.get, "/readingsessions"))
    }

    /// POST /readingsessions — 세션 기록. 응답: bare Long(id).
    @discardableResult
    func add(_ request: ReadingSessionAddRequest) async throws -> Int {
        try await client.requestLong(try Endpoint(.post, "/readingsessions", json: request))
    }

    /// GET /readingsessions/bybook — 책별 세션.
    func fetchByBook(userBookId: Int) async throws -> [ReadingSessionDto] {
        try await client.request(
            Endpoint(.get, "/readingsessions/bybook", queryItems: [
                URLQueryItem(name: "userBookId", value: String(userBookId)),
            ])
        )
    }

    /// GET /readingsessions/stats — 책별 세션 통계. 호출부는 실패 시 `.empty` 폴백 권장.
    func stats(userBookId: Int) async throws -> ReadingSessionStatsDto {
        try await client.request(
            Endpoint(.get, "/readingsessions/stats", queryItems: [
                URLQueryItem(name: "userBookId", value: String(userBookId)),
            ])
        )
    }

    /// GET /readingsessions/streak — 연속 독서. 호출부는 실패 시 `.empty` 폴백 권장.
    func streak() async throws -> StreakDto {
        try await client.request(Endpoint(.get, "/readingsessions/streak"))
    }
}
