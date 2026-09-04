import Foundation

/// refresh 실패 원인 구분.
/// 강제 로그아웃은 `.rejected`(서버가 리프레시 토큰을 명시적으로 거부) 단 한 경우에만 수행한다.
/// 네트워크 오류·5xx·디코딩 실패는 전부 `.transient` — 토큰을 유지하고 다음 요청에서 재시도한다.
enum TokenRefreshError: Error {
    /// 서버가 400/401/403으로 리프레시 토큰 자체를 무효 판정 — 세션 종료가 맞는 유일한 경우.
    case rejected
    /// 일시적 실패 — 토큰을 지우면 안 된다. 원인 에러를 그대로 전파한다.
    case transient(APIError)
}

/// 401 토큰 갱신을 직렬화하는 actor (문서 §2.2, §9.3-2 권고).
/// 동시에 여러 요청이 401을 받아도 refresh는 한 번만 수행하고 결과를 공유한다.
/// 갱신 요청은 인증 인터셉터를 우회해 직접 URLSession으로 보낸다 (무한루프 방지).
actor TokenRefreshCoordinator {
    private let baseURL: URL
    private let tokenStore: KeychainTokenStore
    private var inFlight: Task<String, Error>?

    /// 백그라운드 복귀 직후 네트워크가 아직 살아나지 않은 시점의 refresh 실패가
    /// 로그아웃으로 이어지지 않도록, 연결이 준비될 때까지 잠시 기다리는 전용 세션.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    init(baseURL: URL, tokenStore: KeychainTokenStore) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }

    /// 새 access token을 발급받아 저장 후 반환. 진행 중인 갱신이 있으면 그 결과를 기다린다.
    /// 실패 시 `TokenRefreshError`를 던진다 — 호출부는 `.rejected`일 때만 로그아웃해야 한다.
    func refreshAccessToken() async throws -> String {
        if let task = inFlight {
            return try await task.value
        }

        let baseURL = self.baseURL
        let tokenStore = self.tokenStore
        let task = Task<String, Error> {
            guard let refreshToken = tokenStore.refreshToken() else {
                // Keychain 일시 접근 불가로 nil일 수 있으므로 로그아웃 사유(.rejected)로 보지 않는다.
                throw TokenRefreshError.transient(.auth("로그인이 필요합니다"))
            }

            do {
                return try await Self.requestNewAccessToken(
                    baseURL: baseURL, tokenStore: tokenStore, refreshToken: refreshToken)
            } catch let error as TokenRefreshError {
                // 네트워크 오류만 1초 뒤 1회 재시도 (복귀 직후 연결 끊김 대비).
                // 5xx는 배포 재시작 등 수십 초 지속되는 상태라 즉시 재시도가 무의미하다.
                guard case .transient(.network) = error else { throw error }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return try await Self.requestNewAccessToken(
                    baseURL: baseURL, tokenStore: tokenStore, refreshToken: refreshToken)
            }
        }

        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private static func requestNewAccessToken(
        baseURL: URL,
        tokenStore: KeychainTokenStore,
        refreshToken: String
    ) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 서버 AppVersionEnforcementFilter는 버전 헤더가 없고 UA가 CFNetwork인 요청을
        // "게이트 이전 iOS 구버전"으로 간주해 426을 돌려준다. refresh는 APIClient를
        // 우회하는 별도 세션이라 여기서도 반드시 버전 헤더를 붙여야 한다 —
        // 빠지면 access 토큰 만료(1시간) 이후 모든 요청이 refresh 단계에서 실패한다.
        request.setValue(AppVersionInfo.current, forHTTPHeaderField: "X-App-Version")
        request.setValue("ios", forHTTPHeaderField: "X-App-Platform")
        do {
            request.httpBody = try JSONCoding.encoder.encode(["refreshToken": refreshToken])
        } catch {
            throw TokenRefreshError.transient(.unknown("refresh 요청을 생성하지 못했습니다"))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TokenRefreshError.transient(APIError.wrap(error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw TokenRefreshError.transient(.unknown("알 수 없는 오류가 발생했습니다"))
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 400, 401, 403:
            // 서버가 리프레시 토큰 자체를 무효로 판정 — 유일한 로그아웃 사유.
            throw TokenRefreshError.rejected
        default:
            // 5xx(배포 중 재시작·프록시 502 등)·기타 상태는 일시적 실패 — 토큰 유지.
            throw TokenRefreshError.transient(APIError.from(statusCode: http.statusCode, data: data))
        }

        let tokens: TokenRefreshResponse
        do {
            tokens = try JSONCoding.decoder.decode(TokenRefreshResponse.self, from: data)
        } catch {
            throw TokenRefreshError.transient(.decoding(String(describing: error)))
        }

        tokenStore.save(accessToken: tokens.token, refreshToken: tokens.refreshToken)
        return tokens.token
    }
}
