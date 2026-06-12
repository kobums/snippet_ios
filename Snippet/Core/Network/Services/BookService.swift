import Foundation

/// 도서 API (문서 §3.6) — 검색/인기는 백엔드 프록시.
struct BookService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /books/search — 알라딘 검색 (page 1-base).
    func search(query: String, page: Int = 1) async throws -> [BookSearchDto] {
        try await client.request(
            Endpoint(.get, "/books/search", queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
            ])
        )
    }

    /// GET /books/popular — 국립중앙도서관 인기 대출 도서. 빈 값 파라미터는 미전송.
    func popular(_ query: PopularBooksQuery = PopularBooksQuery()) async throws -> [PopularBookDto] {
        var queryItems: [URLQueryItem] = []
        let optionalParams: [(String, String?)] = [
            ("startDt", query.startDt), ("endDt", query.endDt),
            ("kdc", query.kdc), ("dtlKdc", query.dtlKdc),
            ("age", query.age), ("gender", query.gender),
            ("region", query.region), ("dtlRegion", query.dtlRegion),
        ]
        for (name, value) in optionalParams {
            if let value, !value.isEmpty {
                queryItems.append(URLQueryItem(name: name, value: value))
            }
        }
        queryItems.append(URLQueryItem(name: "pageNo", value: String(query.pageNo)))
        queryItems.append(URLQueryItem(name: "pageSize", value: String(query.pageSize)))
        return try await client.request(Endpoint(.get, "/books/popular", queryItems: queryItems))
    }

    /// GET /books/recommend — 추천 (인증 필요). 호출부는 실패 시 빈 배열 폴백 권장 (문서 §3.6).
    func recommend(limit: Int = 6) async throws -> [BookRecommendDto] {
        try await client.request(
            Endpoint(.get, "/books/recommend", queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
            ])
        )
    }
}
