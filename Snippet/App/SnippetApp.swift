import SwiftUI

@main
struct SnippetApp: App {
    /// UIApplicationDelegate 연결 — APNs 토큰 콜백 수신용.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 앱 전역 인증 세션 — 루트에서 1개 생성해 environment로 주입.
    @State private var session = AuthSession()

    /// 스플래시 최소 노출 + 자동 로그인 체크 완료 여부.
    @State private var didFinishSplash = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !didFinishSplash {
                    SplashView(onFinished: { didFinishSplash = true })
                } else if session.isAuthenticated {
                    RootView()
                        .onAppear {
                            // 로그인 완료 직후 푸시 알림 권한 요청 + APNs 등록.
                            // Flutter 원본: auth_provider.dart:84 로그인 성공 시 fcmService.initialize().
                            PushNotificationManager.shared.requestPermissionAndRegister()
                        }
                } else {
                    LoginView()
                }
            }
            .environment(session)
        }
    }
}
