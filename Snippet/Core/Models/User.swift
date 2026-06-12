import Foundation

/// 사용자 / 인증 응답 모델.
/// POST /auth/login, /auth/register, GET /auth/me 응답과 동일 구조.
/// 로컬 영속화 시에는 token/refreshToken을 제거하고 저장한다 (Keychain 분리, 문서 §5.4).
struct User: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let email: String
    let name: String
    var token: String?
    var refreshToken: String?

    /// 토큰을 제거한 사본 (UserDefaults 저장용).
    var withoutTokens: User {
        var copy = self
        copy.token = nil
        copy.refreshToken = nil
        return copy
    }
}

/// POST /auth/refresh 응답: 둘 다 새로 발급.
struct TokenRefreshResponse: Codable, Sendable {
    let token: String
    let refreshToken: String
}
