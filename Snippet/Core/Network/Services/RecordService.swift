import Foundation

/// 독서 기록 API (문서 §3.5) — 인증 필요.
struct RecordService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /records — 내 기록 전체 (앱 미사용, 백엔드 존재).
    func fetchAll() async throws -> [RecordDto] {
        try await client.request(Endpoint(.get, "/records"))
    }

    /// GET /records/bybook — 책별 기록.
    func fetchByBook(bookId: Int, type: RecordType? = nil) async throws -> [RecordDto] {
        var queryItems = [URLQueryItem(name: "bookId", value: String(bookId))]
        if let type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        return try await client.request(Endpoint(.get, "/records/bybook", queryItems: queryItems))
    }

    /// GET /records/monthly — 월별 기록.
    func fetchMonthly(year: Int? = nil, month: Int? = nil, type: RecordType? = nil) async throws -> [RecordDto] {
        var queryItems: [URLQueryItem] = []
        if let year { queryItems.append(URLQueryItem(name: "year", value: String(year))) }
        if let month { queryItems.append(URLQueryItem(name: "month", value: String(month))) }
        if let type { queryItems.append(URLQueryItem(name: "type", value: type.rawValue)) }
        return try await client.request(Endpoint(.get, "/records/monthly", queryItems: queryItems))
    }

    /// POST /records — 생성. 응답은 bare Long(recordId) (문서 §3.5 경고).
    @discardableResult
    func add(_ request: RecordAddRequest) async throws -> Int {
        try await client.requestLong(try Endpoint(.post, "/records", json: request))
    }

    /// PATCH /records/{id} — 수정.
    @discardableResult
    func update(id: Int, _ request: RecordUpdateRequest) async throws -> RecordDto {
        try await client.request(try Endpoint(.patch, "/records/\(id)", json: request))
    }

    /// DELETE /records/{id}
    func delete(id: Int) async throws {
        try await client.requestVoid(Endpoint(.delete, "/records/\(id)"))
    }
}
