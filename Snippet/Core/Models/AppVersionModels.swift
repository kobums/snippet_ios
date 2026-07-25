import Foundation

/// 앱 버전 정책 (GET /appversion).
///
/// 버전 비교는 전부 서버가 수행하므로 클라이언트는 `updateRequired` /
/// `updateAvailable` 두 값만 보고 동작한다.
struct AppVersionDto: Codable, Equatable, Sendable {
    let platform: String
    let currentVersion: String?
    let minVersion: String?
    let latestVersion: String?
    let updateRequired: Bool
    let updateAvailable: Bool
    let storeUrl: String?
    let message: String?

    /// 조회 실패 시 폴백 — 절대 차단하지 않는다 (서버가 죽었다고 앱을 잠글 수는 없다).
    static let notRequired = AppVersionDto(
        platform: "unknown",
        currentVersion: nil,
        minVersion: nil,
        latestVersion: nil,
        updateRequired: false,
        updateAvailable: false,
        storeUrl: nil,
        message: nil
    )

    /// 스토어 URL — 서버 미설정 시 App Store 주소로 폴백.
    var resolvedStoreURL: URL {
        if let storeUrl, let url = URL(string: storeUrl) {
            return url
        }
        return AppVersionInfo.fallbackStoreURL
    }
}

/// 현재 실행 중인 앱의 버전 정보.
enum AppVersionInfo {
    /// CFBundleShortVersionString (예: "1.0.28").
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// 서버가 storeUrl을 안 내려줬을 때 쓰는 App Store 주소.
    static let fallbackStoreURL = URL(string: "https://apps.apple.com/kr/app/id6759643636")!
}
