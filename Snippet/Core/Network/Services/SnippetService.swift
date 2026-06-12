import Foundation

/// 스니펫 API (문서 §3.2) — cards는 비로그인 허용.
struct SnippetService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /snippets/cards — 스와이프 카드 조회.
    /// `remainingToday == -1` 비로그인(무제한), `0` 일일 제한 도달.
    func fetchCards(
        count: Int = APIConfig.snippetFetchCount,
        excludeIds: [Int]? = nil
    ) async throws -> SnippetCardsResponse {
        var queryItems = [URLQueryItem(name: "count", value: String(count))]
        if let excludeIds, !excludeIds.isEmpty {
            queryItems.append(URLQueryItem(
                name: "excludeIds",
                value: excludeIds.map(String.init).joined(separator: ",")
            ))
        }
        return try await client.request(Endpoint(.get, "/snippets/cards", queryItems: queryItems))
    }

    /// GET /snippets/archive — 아카이브 목록 (인증 필요).
    func fetchArchive() async throws -> [SnippetArchive] {
        try await client.request(Endpoint(.get, "/snippets/archive"))
    }

    /// POST /snippets/archive — 아카이브 추가 (스와이프 오른쪽). 응답: bare Long (archive id).
    @discardableResult
    func addArchive(snippetId: Int) async throws -> Int {
        try await client.requestLong(
            try Endpoint(.post, "/snippets/archive", json: ["snippetId": snippetId])
        )
    }

    /// DELETE /snippets/archive/{snippetId} — 아카이브 제거.
    func removeArchive(snippetId: Int) async throws {
        try await client.requestVoid(Endpoint(.delete, "/snippets/archive/\(snippetId)"))
    }

    /// POST /snippets/{id}/skip — 스킵 (스와이프 왼쪽). 비로그인 시 서버 no-op.
    func skip(snippetId: Int) async throws {
        try await client.requestVoid(Endpoint(.post, "/snippets/\(snippetId)/skip"))
    }
}
