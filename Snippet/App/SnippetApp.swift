import SwiftUI

@main
struct SnippetApp: App {
    /// UIApplicationDelegate 연결 — APNs 토큰 콜백 수신용.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 앱 전역 인증 세션 — 루트에서 1개 생성해 environment로 주입.
    @State private var session = AuthSession()

    /// 앱 버전 정책 게이트 — 강제 업데이트 차단 판정.
    @State private var versionGate = AppVersionGate()

    /// 스플래시 최소 노출 + 자동 로그인 체크 완료 여부.
    @State private var didFinishSplash = false

    /// 포그라운드 복귀 시 버전 재확인용.
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                // 강제 업데이트는 로그인 여부와 무관하게 앱 전체를 대체한다.
                if versionGate.isBlocked {
                    ForceUpdateView(policy: versionGate.policy)
                } else if !didFinishSplash {
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
            .environment(versionGate)
            // 권장 업데이트는 닫을 수 있는 안내로만 노출.
            .alert("새 버전이 있습니다", isPresented: $versionGate.isShowingSoftPrompt) {
                Link("업데이트", destination: versionGate.policy.resolvedStoreURL)
                Button("나중에", role: .cancel) { versionGate.skipSoftPrompt() }
            } message: {
                Text(versionGate.policy.message ?? "최신 버전으로 업데이트하면 새로운 기능을 사용할 수 있어요.")
            }
            .task {
                await versionGate.check()
            }
            // 백그라운드에 오래 머문 뒤 돌아온 경우에도 정책을 반영한다.
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await versionGate.check() }
            }
        }
    }
}
