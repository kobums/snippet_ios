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

    // MARK: - 델리게이트 선점

    /// 앱 시작 직후(`AppDelegate.didFinishLaunchingWithOptions`)에 호출한다.
    ///
    /// `FirebaseApp.configure()` 직후 Firebase는 캐시된 등록 토큰으로
    /// `messaging(_:didReceiveRegistrationToken:)`을 **한 번** 발화한다.
    /// 델리게이트를 로그인 이후에 대입하면 이 발화를 놓치고, 토큰이 갱신되기
    /// 전까지 콜백이 다시 오지 않아 서버 등록이 영구히 누락된다.
    /// 콜드 스타트 알림 탭 처리를 위해 UNUserNotificationCenter 델리게이트도 함께 선점한다.
    func configureDelegates() {
        UNUserNotificationCenter.current().delegate = self
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
    }

    // MARK: - 권한 요청 + APNs 등록

    /// 앱 초기화 완료 직후(또는 로그인 성공 직후) 호출.
    /// UNUserNotificationCenter 권한을 요청하고, 허용 시 APNs 등록을 트리거한다.
    func requestPermissionAndRegister() {
        // 멱등 — AppDelegate에서 이미 선점했더라도 다시 대입해 안전하게 보장한다.
        configureDelegates()
        let center = UNUserNotificationCenter.current()
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
        // FCM: APNs 토큰을 Firebase에 전달.
        Messaging.messaging().apnsToken = deviceToken
        // 델리게이트 콜백은 토큰이 *변경*될 때만 발화하므로, 이미 발급된 토큰은
        // 여기서 능동 조회해야 서버에 반영된다. APNs 토큰 대입 직후라 조회가 안전하다.
        // (Android `FcmTokenManager.registerCurrentToken()`과 동일한 역할)
        syncCurrentToken()
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

    // MARK: - 능동 토큰 조회

    /// 현재 FCM 등록 토큰을 조회해 서버에 등록한다.
    ///
    /// `messaging(_:didReceiveRegistrationToken:)`은 토큰이 **새로 발급/갱신될 때만** 호출된다.
    /// 재실행처럼 토큰이 그대로인 경우 콜백이 오지 않으므로, 이 경로가 없으면
    /// 서버의 `u_fcmtoken`이 영구히 비어 있게 된다.
    func syncCurrentToken() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("[Push] FCM 토큰 조회 실패: \(error.localizedDescription)")
                return
            }
            guard let token else { return }
            Task { @MainActor in
                await self?.registerTokenWithServer(token)
            }
        }
        #endif
    }

    // MARK: - 서버 토큰 등록

    /// POST /users/fcmtoken — 실패해도 앱 동작은 막지 않되, 원인 추적을 위해 로그는 남긴다.
    /// (기존에는 `try?`로 삼켜서 "전송 실패"와 "전송 시도 자체가 없음"이 구분되지 않았다.)
    private func registerTokenWithServer(_ token: String) async {
        do {
            try await userService.registerFCMToken(token)
            print("[Push] FCM 토큰 서버 등록 성공")
        } catch {
            print("[Push] FCM 토큰 서버 등록 실패: \(error)")
        }
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
