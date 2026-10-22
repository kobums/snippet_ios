import Foundation

extension Notification.Name {
    /// 서재 책이 추가·수정·삭제됐을 때 발화하는 브로드캐스트.
    /// 화면마다 LibraryViewModel 인스턴스를 따로 들고 있어서, 책 상세에서 완독 처리를 해도
    /// 대시보드의 월별 집계·독서 목표 달성 권수는 당겨서 새로고침하기 전까지 옛 숫자였다.
    /// DashboardViewModel이 수신해 조용히 다시 조회한다 (Android의 userBookChangedEvents와 동일 역할).
    /// object에 수정된 UserBookDto가 실려 오면 목록을 통째로 다시 받지 않고 그 책만 갈아끼울 수 있다
    /// (추가·삭제는 멤버십 자체가 바뀌므로 object가 nil이고, 수신 측이 전체를 다시 조회한다).
    static let snippetUserBookChanged = Notification.Name("com.gowoobro.snippet.userBookChanged")
}

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
        let id = try await client.requestLong(try Endpoint(.post, "/userbooks", json: request))
        Self.broadcastChange(nil)
        return id
    }

    /// PATCH /userbooks/{id} — 부분 업데이트 (nil 키는 전송 생략).
    @discardableResult
    func update(id: Int, _ request: UserBookUpdateRequest) async throws -> UserBookDto {
        let updated: UserBookDto = try await client.request(
            try Endpoint(.patch, "/userbooks/\(id)", json: request))
        Self.broadcastChange(updated)
        return updated
    }

    /// PUT /userbooks/{id} — PATCH와 동일 동작 (앱 미사용).
    @discardableResult
    func replace(id: Int, _ request: UserBookUpdateRequest) async throws -> UserBookDto {
        try await client.request(try Endpoint(.put, "/userbooks/\(id)", json: request))
    }

    /// DELETE /userbooks/{id}
    func delete(id: Int) async throws {
        try await client.requestVoid(Endpoint(.delete, "/userbooks/\(id)"))
        Self.broadcastChange(nil)
    }

    /// 성공한 쓰기 요청 뒤에만 호출한다 (실패하면 화면을 흔들 이유가 없다).
    private static func broadcastChange(_ updated: UserBookDto?) {
        NotificationCenter.default.post(name: .snippetUserBookChanged, object: updated)
    }

    private static func yearMonthQuery(_ year: Int?, _ month: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let year { items.append(URLQueryItem(name: "year", value: String(year))) }
        if let month { items.append(URLQueryItem(name: "month", value: String(month))) }
        return items
    }
}
