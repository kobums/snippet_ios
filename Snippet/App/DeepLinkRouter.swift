import SwiftUI

// MARK: - DeepLinkRouter

/// 푸시 알림 딥링크 → 탭 전환 라우터.
///
/// ## 딥링크 계약 (Android와 공유)
/// 푸시 페이로드의 `userInfo`에 문자열 키 **"route"**(또는 별칭 **"tab"**)가 담긴다.
/// 값은 `snippet` / `dashboard` / `records` / `library` / `profile` 중 하나이며,
/// 알림 탭 시 해당 탭으로 전환한다.
///
/// ## 동작
/// `PushNotificationManager.didReceive`가 `handle(userInfo:)`를 호출해 `pendingTab`을 설정한다.
/// `RootView`가 `pendingTab`을 관찰해 `selectedTab`으로 반영하고 `pendingTab = nil`로 소비한다.
/// 콜드 스타트(종료 상태에서 알림 탭으로 실행)의 경우, 인증 후 `RootView`가 나타날 때
/// 보관된 `pendingTab`이 `.task`/`.onAppear`에서 소비된다.
@Observable
@MainActor
final class DeepLinkRouter {

    /// 앱 전역 공유 인스턴스 (Push 델리게이트는 SwiftUI 환경 밖에서 접근하므로 싱글톤 사용).
    static let shared = DeepLinkRouter()

    /// 전환 대기 중인 탭. nil이면 대기 없음.
    var pendingTab: SnippetTab?

    private init() {}

    /// 푸시 `userInfo`에서 라우트를 읽어 `pendingTab`을 설정한다.
    /// - Parameter userInfo: `UNNotificationResponse`의 `userInfo`.
    func handle(userInfo: [AnyHashable: Any]) {
        guard let route = routeString(from: userInfo),
              let tab = Self.tab(for: route) else {
            return
        }
        pendingTab = tab
    }

    /// userInfo에서 "route" 우선, 없으면 "tab" 별칭을 문자열로 추출.
    private func routeString(from userInfo: [AnyHashable: Any]) -> String? {
        if let route = userInfo["route"] as? String { return route }
        if let tab = userInfo["tab"] as? String { return tab }
        return nil
    }

    /// 라우트 문자열을 SnippetTab으로 매핑 (대소문자 무시).
    static func tab(for route: String) -> SnippetTab? {
        switch route.lowercased() {
        case "snippet": return .snippet
        case "dashboard": return .dashboard
        case "records": return .records
        case "library": return .library
        case "profile": return .profile
        default: return nil
        }
    }
}
