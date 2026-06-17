import UIKit
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// 푸시 알림 매니저 (문서 §2 FCM 섹션 네이티브 매핑).
///
/// ## Firebase 자동 활성화
/// Firebase iOS SDK(FirebaseMessaging)를 SPM으로 추가하면 `#if canImport(FirebaseMessaging)`로
/// FCM 경로가 **코드 수정 없이 자동 활성화**된다:
/// - APNs 토큰을 `Messaging.messaging().apnsToken`에 전달
/// - FCM 등록 토큰(fcmToken)을 `messaging(_:didReceiveRegistrationToken:)`에서 서버에 전송
/// SDK가 없으면 APNs 토큰을 직접 서버에 등록하는 폴백으로 동작한다.
/// GoogleService-Info.plist·Push capability 추가 절차는 `FCM-SETUP.md` 참고.
@MainActor
final class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()

    private let userService = UserService()

    private override init() {
        super.init()
    }

    // MARK: - 권한 요청 + APNs 등록

    /// 앱 초기화 완료 직후(또는 로그인 성공 직후) 호출.
    /// UNUserNotificationCenter 권한을 요청하고, 허용 시 APNs 등록을 트리거한다.
    func requestPermissionAndRegister() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[Push] 권한 요청 오류: \(error.localizedDescription)")
            }
            guard granted else {
                print("[Push] 사용자가 알림 권한을 거부했습니다.")
                return
            }
            // 권한 허용 시 메인 스레드에서 APNs 등록
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - AppDelegate 콜백 수신

    /// AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)에서 호출.
    /// - Parameter deviceToken: APNs가 발급한 기기 토큰.
    func apnsTokenReceived(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        #if DEBUG
        // 기기 토큰은 민감 정보 — DEBUG 빌드에서 앞·뒤 일부만 마스킹해 출력한다.
        let masked = tokenString.count > 8
            ? "\(tokenString.prefix(4))…\(tokenString.suffix(4))"
            : "****"
        print("[Push] APNs 토큰 수신: \(masked)")
        #endif

        #if canImport(FirebaseMessaging)
        // FCM: APNs 토큰을 Firebase에 전달 → FCM 등록 토큰은 messaging(_:didReceiveRegistrationToken:)에서 서버 전송
        Messaging.messaging().apnsToken = deviceToken
        #else
        // 폴백: APNs 토큰을 직접 서버에 등록
        Task {
            await registerTokenWithServer(tokenString)
        }
        #endif
    }

    /// AppDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)에서 호출.
    func apnsRegistrationFailed(_ error: Error) {
        print("[Push] APNs 등록 실패: \(error.localizedDescription)")
    }

    // MARK: - 서버 토큰 등록

    /// POST /users/fcmtoken — 실패는 무시 (문서 §2 호출 시점 규칙).
    ///
    /// ## Firebase 전환 지점
    /// Firebase SDK 추가 후 이 메서드는 `messaging(_:didReceiveRegistrationToken:)` 델리게이트
    /// 메서드 내에서 호출해야 한다. fcmToken 파라미터를 APNs 토큰 대신 FCM 등록 토큰으로 교체.
    private func registerTokenWithServer(_ token: String) async {
        try? await userService.registerFCMToken(token)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    /// 앱이 포그라운드 상태일 때 알림 수신 — 배너·배지·소리 모두 표시.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    /// 사용자가 알림을 탭하거나 액션을 선택했을 때 호출.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        #if DEBUG
        // userInfo에는 푸시 페이로드 전체가 담겨 민감 정보가 포함될 수 있어 DEBUG 빌드에서만 로깅한다.
        print("[Push] 알림 탭 수신 — route: \(userInfo["route"] ?? userInfo["tab"] ?? "nil")")
        #endif
        // 딥링크 라우팅: userInfo["route"](또는 "tab") → 탭 전환.
        // RootView가 DeepLinkRouter.pendingTab을 관찰해 실제 전환을 수행한다.
        Task { @MainActor in
            DeepLinkRouter.shared.handle(userInfo: userInfo)
            completionHandler()
        }
    }
}

// MARK: - MessagingDelegate (Firebase SDK 추가 시 자동 활성화)

#if canImport(FirebaseMessaging)
extension PushNotificationManager: MessagingDelegate {

    /// FCM 등록 토큰 발급/갱신 시 호출 — 서버에 등록.
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("[Push] FCM 등록 토큰 수신")
        Task { @MainActor in
            await self.registerTokenWithServer(fcmToken)
        }
    }
}
#endif
