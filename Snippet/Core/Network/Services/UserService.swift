import Foundation

/// 사용자 부가 API (문서 §3.11).
struct UserService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// POST /users/fcmtoken — FCM 토큰 등록 (인증 필요).
    /// 호출 시점: 앱 시작 시 + onTokenRefresh + 로그인 성공 직후. **실패는 무시** (문서 §3.11).
    func registerFCMToken(_ token: String) async throws {
        try await client.requestVoid(
            try Endpoint(.post, "/users/fcmtoken", json: ["fcmToken": token])
        )
    }
}
