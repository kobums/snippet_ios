import Foundation

/// 사용자 서재 API (문서 §3.3) — 전부 인증 필요.
struct UserBookService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /userbooks — 전체 목록 (앱 미사용, 백엔드 존재).
    func fetchAll() async throws -> [UserBookDto] {
        try await client.request(Endpoint(.get, "/userbooks"))
    }

    /// GET /userbooks/{id} — 단건 (앱 미사용).
    func fetch(id: Int) async throws -> UserBookDto {
        try await client.request(Endpoint(.get, "/userbooks/\(id)"))
    }

    /// GET /userbooks/monthly — 해당 월 활동 도서. year/month는 둘 다 줘야 적용 (생략 시 현재 월).
    func fetchMonthly(year: Int? = nil, month: Int? = nil) async throws -> [UserBookDto] {
        try await client.request(
            Endpoint(.get, "/userbooks/monthly", queryItems: Self.yearMonthQuery(year, month))
        )
    }

    /// GET /userbooks/progress — 대시보드 진행 탭 (waiting/reading 전체 + 해당 월 completed).
    func fetchProgress(year: Int? = nil, month: Int? = nil) async throws -> [UserBookDto] {
        try await client.request(
            Endpoint(.get, "/userbooks/progress", queryItems: Self.yearMonthQuery(year, month))
        )
    }

    /// GET /userbooks/all — 서재용 페이지네이션 (최신순, page 0-base).
    func fetchPaged(page: Int = 0, size: Int = 20) async throws -> [UserBookDto] {
        try await client.request(
            Endpoint(.get, "/userbooks/all", queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ])
        )
    }

    /// POST /userbooks — 서재 추가. 응답은 bare Long(userBookId) — 수신 후 목록 재조회 권장 (문서 §3.3 경고).
    @discardableResult
    func add(_ request: LibraryAddRequest) async throws -> Int {
        try await client.requestLong(try Endpoint(.post, "/userbooks", json: request))
    }

    /// PATCH /userbooks/{id} — 부분 업데이트 (nil 키는 전송 생략).
    @discardableResult
    func update(id: Int, _ request: UserBookUpdateRequest) async throws -> UserBookDto {
        try await client.request(try Endpoint(.patch, "/userbooks/\(id)", json: request))
    }

    /// PUT /userbooks/{id} — PATCH와 동일 동작 (앱 미사용).
    @discardableResult
    func replace(id: Int, _ request: UserBookUpdateRequest) async throws -> UserBookDto {
        try await client.request(try Endpoint(.put, "/userbooks/\(id)", json: request))
    }

    /// DELETE /userbooks/{id}
    func delete(id: Int) async throws {
        try await client.requestVoid(Endpoint(.delete, "/userbooks/\(id)"))
    }

    private static func yearMonthQuery(_ year: Int?, _ month: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let year { items.append(URLQueryItem(name: "year", value: String(year))) }
        if let month { items.append(URLQueryItem(name: "month", value: String(month))) }
        return items
    }
}
