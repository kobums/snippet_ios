import Foundation
import Security

/// JWT access/refresh 토큰 저장소.
/// Flutter SecureStorage 키(`auth_token`, `auth_refresh_token`)를 그대로 유지한다 (문서 §5.4, §6.2).
///
/// 1차 저장소는 Keychain(kSecClassGenericPassword)이다.
/// 단, **미서명/ad-hoc 시뮬레이터 빌드**는 `application-identifier`(keychain-access-group)
/// 엔타이틀먼트가 없어 `SecItemAdd`가 `errSecMissingEntitlement(-34018)`로 실패한다.
/// 이 경우에만 UserDefaults로 폴백해 개발 빌드에서도 토큰이 유지되게 한다.
/// 정식 서명 빌드(배포/실기기)에서는 Keychain이 정상 동작하므로 폴백은 사용되지 않는다.
final class KeychainTokenStore: Sendable {
    static let shared = KeychainTokenStore()

    private let service = "com.gowoobro.snippet"
    private let accessTokenKey = "auth_token"
    private let refreshTokenKey = "auth_refresh_token"

    /// Keychain이 불가용일 때만 쓰는 폴백 저장소. (UserDefaults.standard는 스레드 안전)
    private var fallbackDefaults: UserDefaults { .standard }
    private let fallbackPrefix = "keychain_fallback_"

    init() {}

    // MARK: - Read

    func accessToken() -> String? {
        read(accessTokenKey)
    }

    func refreshToken() -> String? {
        read(refreshTokenKey)
    }

    // MARK: - Write

    func save(accessToken: String) {
        write(accessToken, for: accessTokenKey)
    }

    func save(refreshToken: String) {
        write(refreshToken, for: refreshTokenKey)
    }

    func save(accessToken: String, refreshToken: String) {
        write(accessToken, for: accessTokenKey)
        write(refreshToken, for: refreshTokenKey)
    }

    // MARK: - Delete

    func clearAccessToken() {
        delete(accessTokenKey)
    }

    func clearAll() {
        delete(accessTokenKey)
        delete(refreshTokenKey)
    }

    // MARK: - Keychain primitives

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    private func read(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8),
           !value.isEmpty {
            return value
        }
        // 항목 미존재(errSecItemNotFound) 또는 Keychain 자체 불가용(미서명 시뮬레이터 -34018)
        // 일 때만 폴백을 확인한다. 잠금 등 일시적 접근 오류(errSecInteractionNotAllowed)에서는
        // 폴백을 신뢰하지 않고 nil을 반환해 stale/평문 값 노출을 막는다.
        if status == errSecItemNotFound || status == errSecMissingEntitlement {
            return fallbackDefaults.string(forKey: fallbackPrefix + key)
        }
        return nil
    }

    private func write(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status == errSecSuccess {
            // Keychain 저장 성공 → 폴백 잔재 제거.
            fallbackDefaults.removeObject(forKey: fallbackPrefix + key)
        } else if status == errSecMissingEntitlement {
            // Keychain 자체가 불가용한 환경(미서명 시뮬레이터, -34018)에서만 UserDefaults 폴백.
            // 잠금 등 일시적 오류(errSecInteractionNotAllowed)에서는 평문 저장하지 않는다.
            fallbackDefaults.set(value, forKey: fallbackPrefix + key)
        }
    }

    private func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
        fallbackDefaults.removeObject(forKey: fallbackPrefix + key)
    }
}
