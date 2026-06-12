import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// UIApplicationDelegate — SwiftUI 앱에서 `@UIApplicationDelegateAdaptor`로 연결.
///
/// 역할: APNs 원격 알림 토큰 수신 콜백을 `PushNotificationManager`로 전달한다.
/// SwiftUI `@main` 진입점은 `SnippetApp.swift`가 담당하므로 이 클래스는 직접
/// `application(_:didFinishLaunchingWithOptions:)`를 오버라이드하지 않아도 된다.
///
/// ## Firebase 자동 활성화
/// Firebase SDK(FirebaseCore)를 SPM으로 추가하면 `#if canImport`로 아래 `FirebaseApp.configure()`가
/// 자동 활성화된다(코드 수정 불필요). GoogleService-Info.plist·Push capability 추가는 `FCM-SETUP.md` 참고.
final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - 앱 시작

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
        return true
    }

    // MARK: - APNs 토큰 수신

    /// APNs 등록 성공 — 토큰을 `PushNotificationManager`로 전달.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.apnsTokenReceived(deviceToken)
        }
    }

    /// APNs 등록 실패 — 오류를 `PushNotificationManager`로 전달.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.apnsRegistrationFailed(error)
        }
    }
}
