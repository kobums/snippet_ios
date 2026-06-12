import Foundation

/// 건의 API (문서 §3.9) — 인증 필요.
struct SuggestionService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// POST /suggestions — 건의 등록. title이 빈 문자열이면 키 자체가 생략된다.
    @discardableResult
    func submit(category: SuggestionCategory, title: String?, content: String) async throws -> SuggestionDto {
        try await client.request(
            try Endpoint(.post, "/suggestions", json: SuggestionRequest(
                category: category, title: title, content: content
            ))
        )
    }

    /// GET /suggestions/mine — 내 건의 목록 (앱 미사용, 백엔드 존재).
    func mine() async throws -> [SuggestionDto] {
        try await client.request(Endpoint(.get, "/suggestions/mine"))
    }
}
