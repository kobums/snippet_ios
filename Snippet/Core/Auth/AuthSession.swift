import Foundation
import Observation

/// 앱 전역 인증 세션 (문서 §5).
/// - 토큰: Keychain (`KeychainTokenStore`)
/// - 사용자 프로필: UserDefaults `current_user` — **토큰을 제거하고** 저장 (문서 §5.4 개선 권고)
/// - 자동 로그인: 서버 호출 없이 로컬만 확인 (문서 §5.2)
/// - refresh 실패 시 `.snippetForceLogout` 브로드캐스트 수신 → 강제 로그아웃
@MainActor
@Observable
final class AuthSession {
    private(set) var currentUser: User?
    private(set) var isAuthenticated = false

    /// refresh 실패로 강제 로그아웃된 경우 true — 루트 뷰가 로그인 화면으로 리셋하고 안내 노출.
    private(set) var wasForcedLogout = false

    private let authService: AuthService
    private let tokenStore: KeychainTokenStore
    private let defaults: UserDefaults

    private static let currentUserKey = "current_user"

    @ObservationIgnored
    nonisolated(unsafe) private var forceLogoutObserver: NSObjectProtocol?

    init(
        authService: AuthService = AuthService(),
        tokenStore: KeychainTokenStore = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.defaults = defaults

        forceLogoutObserver = NotificationCenter.default.addObserver(
            forName: .snippetForceLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleForcedLogout()
            }
        }
    }

    deinit {
        if let forceLogoutObserver {
            NotificationCenter.default.removeObserver(forceLogoutObserver)
        }
    }

    // MARK: - 자동 로그인

    /// 스플래시에서 호출 — 서버 호출 없이 Keychain 토큰 + 저장된 프로필 존재 여부만 확인.
    /// 토큰 만료는 이후 첫 API의 401 → refresh로 처리된다.
    @discardableResult
    func checkAuth() -> Bool {
        guard tokenStore.accessToken() != nil,
              let data = defaults.data(forKey: Self.currentUserKey),
              let user = try? JSONDecoder().decode(User.self, from: data)
        else {
            isAuthenticated = false
            currentUser = nil
            return false
        }
        currentUser = user
        isAuthenticated = true
        return true
    }

    // MARK: - 인증 액션

    /// 가입 전 이메일 인증코드 발송.
    func sendEmailCode(email: String) async throws {
        try await authService.sendEmailCode(email: email)
    }

    /// 로그인 — 성공 시 토큰은 Keychain, 프로필(토큰 제외)은 UserDefaults에 저장.
    func login(email: String, password: String) async throws {
        let user = try await authService.login(email: email, password: password)
        establishSession(with: user)
    }

    /// 회원가입 — 토큰 즉시 발급, 로그인과 동일하게 세션 수립.
    func register(email: String, password: String, name: String, code: String) async throws {
        let user = try await authService.register(email: email, password: password, name: name, code: code)
        establishSession(with: user)
    }

    /// 로그아웃 — 서버 호출 없음, 로컬 데이터만 삭제 (문서 §5.3).
    func logout() {
        clearLocalSession()
    }

    /// 회원탈퇴 — DELETE /auth/account 성공 후 로컬 전체 삭제.
    func deleteAccount() async throws {
        try await authService.deleteAccount()
        clearLocalSession()
    }

    /// 강제 로그아웃 안내를 사용자에게 노출한 뒤 호출해 플래그를 해제.
    func acknowledgeForcedLogout() {
        wasForcedLogout = false
    }

    // MARK: - Private

    private func establishSession(with user: User) {
        if let token = user.token {
            if let refreshToken = user.refreshToken {
                tokenStore.save(accessToken: token, refreshToken: refreshToken)
            } else {
                tokenStore.save(accessToken: token)
            }
        }
        persist(user: user)
        currentUser = user.withoutTokens
        isAuthenticated = true
        wasForcedLogout = false
    }

    /// 토큰을 제거한 프로필만 UserDefaults에 저장 (평문 토큰 저장 방지).
    private func persist(user: User) {
        if let data = try? JSONEncoder().encode(user.withoutTokens) {
            defaults.set(data, forKey: Self.currentUserKey)
        }
    }

    private func clearLocalSession() {
        tokenStore.clearAll()
        defaults.removeObject(forKey: Self.currentUserKey)
        currentUser = nil
        isAuthenticated = false
    }

    private func handleForcedLogout() {
        guard isAuthenticated else { return }
        clearLocalSession()
        wasForcedLogout = true
    }
}
