import Foundation

/// 인증 API (문서 §3.1) — `/auth/**` 는 인증 불필요.
struct AuthService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// POST /auth/emailcode — 가입 전 이메일 인증코드 발송.
    func sendEmailCode(email: String) async throws {
        try await client.requestVoid(
            try Endpoint(.post, "/auth/emailcode", json: ["email": email])
        )
    }

    /// POST /auth/register — 회원가입 (토큰 즉시 발급).
    func register(email: String, password: String, name: String, code: String) async throws -> User {
        try await client.request(
            try Endpoint(.post, "/auth/register", json: [
                "email": email,
                "password": password,
                "name": name,
                "code": code,
            ])
        )
    }

    /// POST /auth/login
    func login(email: String, password: String) async throws -> User {
        try await client.request(
            try Endpoint(.post, "/auth/login", json: [
                "email": email,
                "password": password,
            ])
        )
    }

    /// DELETE /auth/account — 회원탈퇴 (Bearer 토큰으로 본인 식별).
    func deleteAccount() async throws {
        try await client.requestVoid(Endpoint(.delete, "/auth/account"))
    }

    /// GET /auth/me — 토큰 유효성 검증용 (앱 미사용, 백엔드 존재).
    func me() async throws -> User {
        try await client.request(Endpoint(.get, "/auth/me"))
    }
}
