import Foundation

/// 앱 버전 정책 API — 인증 불필요 (로그인 전에도 호출).
struct AppVersionService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// GET /appversion?platform=ios&version={현재 버전}
    func check(version: String = AppVersionInfo.current) async throws -> AppVersionDto {
        try await client.request(
            Endpoint(.get, "/appversion", queryItems: [
                URLQueryItem(name: "platform", value: "ios"),
                URLQueryItem(name: "version", value: version),
            ])
        )
    }
}
