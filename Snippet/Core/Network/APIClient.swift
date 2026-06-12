import Foundation

extension Notification.Name {
    /// refresh 실패 시 강제 로그아웃 브로드캐스트 (문서 §9.3-6).
    /// AuthSession이 수신해 로컬 인증 데이터를 정리하고 로그인 화면으로 리셋한다.
    static let snippetForceLogout = Notification.Name("com.gowoobro.snippet.forceLogout")
}

/// URLSession async/await 기반 API 클라이언트.
/// - 모든 요청에 `Authorization: Bearer {accessToken}` 자동 주입 (토큰 없으면 헤더 생략)
/// - 401 수신 시 actor 직렬화된 refresh 후 원 요청 1회 재시도 (문서 §2.2)
/// - `/auth/` 경로 401은 갱신 시도 없이 그대로 에러 전파
final class APIClient: Sendable {
    static let shared = APIClient()

    let baseURL: URL
    private let session: URLSession
    private let tokenStore: KeychainTokenStore
    private let refreshCoordinator: TokenRefreshCoordinator

    init(
        baseURL: URL = APIConfig.baseURL,
        tokenStore: KeychainTokenStore = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.refreshCoordinator = TokenRefreshCoordinator(baseURL: baseURL, tokenStore: tokenStore)

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public request API

    /// JSON 객체/배열 응답을 디코딩해 반환.
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let (data, _) = try await perform(endpoint)
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// 응답 바디를 무시하는 요청 (200/204 바디 없음 엔드포인트).
    func requestVoid(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    /// bare Long(숫자 하나) 응답 처리 — POST /userbooks, /records, /readingsessions,
    /// /snippets/archive (문서 §9.3-3: JSON 객체 디코더에 넣지 말 것).
    func requestLong(_ endpoint: Endpoint) async throws -> Int {
        let (data, _) = try await perform(endpoint)
        if let value = try? JSONCoding.decoder.decode(Int.self, from: data) {
            return value
        }
        if let string = String(data: data, encoding: .utf8),
           let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return value
        }
        throw APIError.decoding("bare Long 응답을 파싱하지 못했습니다: \(String(data: data, encoding: .utf8) ?? "")")
    }

    // MARK: - Core

    /// 요청 수행 + 401 refresh-재시도 + 에러 매핑.
    private func perform(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        var request = try makeRequest(endpoint)
        var (data, response) = try await send(request)

        // 401 처리: /auth/ 경로는 갱신 시도 없이 전파 (문서 §2.2)
        if response.statusCode == 401, !endpoint.path.contains("/auth/") {
            guard tokenStore.refreshToken() != nil else {
                tokenStore.clearAccessToken()
                throw APIError.from(statusCode: 401, data: data)
            }

            let newToken: String
            do {
                newToken = try await refreshCoordinator.refreshAccessToken()
            } catch {
                // 갱신 실패 → 토큰 전체 삭제 + 강제 로그아웃 브로드캐스트
                tokenStore.clearAll()
                NotificationCenter.default.post(name: .snippetForceLogout, object: nil)
                throw APIError.auth("세션이 만료되었습니다. 다시 로그인해주세요")
            }

            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            (data, response) = try await send(request)

            // 갱신된 토큰으로 재시도했는데도 401이면 더 이상 회복 불가 →
            // 토큰 정리 + 강제 로그아웃 (무한 refresh/retry 루프 방지, 문서 §9.3-6)
            if response.statusCode == 401 {
                tokenStore.clearAll()
                NotificationCenter.default.post(name: .snippetForceLogout, object: nil)
                throw APIError.auth("세션이 만료되었습니다. 다시 로그인해주세요")
            }
        }

        guard (200..<300).contains(response.statusCode) else {
            throw APIError.from(statusCode: response.statusCode, data: data)
        }
        return (data, response)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.wrap(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("알 수 없는 오류가 발생했습니다")
        }
        return (data, http)
    }

    private func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        let relativePath = endpoint.path.hasPrefix("/")
            ? String(endpoint.path.dropFirst())
            : endpoint.path
        let url = baseURL.appendingPathComponent(relativePath)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.unknown("잘못된 요청 주소입니다")
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let finalURL = components.url else {
            throw APIError.unknown("잘못된 요청 주소입니다")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = APIConfig.requestTimeout
        request.httpBody = endpoint.body
        if let contentType = endpoint.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        // 토큰이 있으면 Bearer 주입, 없으면 헤더 없이 전송 (스니펫 카드 비로그인 허용)
        if let token = tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
