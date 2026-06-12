import Foundation

/// 401 토큰 갱신을 직렬화하는 actor (문서 §2.2, §9.3-2 권고).
/// 동시에 여러 요청이 401을 받아도 refresh는 한 번만 수행하고 결과를 공유한다.
/// 갱신 요청은 인증 인터셉터를 우회해 직접 URLSession으로 보낸다 (무한루프 방지).
actor TokenRefreshCoordinator {
    private let baseURL: URL
    private let tokenStore: KeychainTokenStore
    private var inFlight: Task<String, Error>?

    init(baseURL: URL, tokenStore: KeychainTokenStore) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }

    /// 새 access token을 발급받아 저장 후 반환. 진행 중인 갱신이 있으면 그 결과를 기다린다.
    func refreshAccessToken() async throws -> String {
        if let task = inFlight {
            return try await task.value
        }

        let baseURL = self.baseURL
        let tokenStore = self.tokenStore
        let task = Task<String, Error> {
            guard let refreshToken = tokenStore.refreshToken() else {
                throw APIError.auth("로그인이 필요합니다")
            }

            var request = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
            request.httpMethod = "POST"
            request.timeoutInterval = APIConfig.requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.encoder.encode(["refreshToken": refreshToken])

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw APIError.wrap(error)
            }

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.auth("세션이 만료되었습니다. 다시 로그인해주세요")
            }

            let tokens: TokenRefreshResponse
            do {
                tokens = try JSONCoding.decoder.decode(TokenRefreshResponse.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }

            tokenStore.save(accessToken: tokens.token, refreshToken: tokens.refreshToken)
            return tokens.token
        }

        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
