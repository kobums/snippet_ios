import SwiftUI
import UserNotifications

/// 탭 4 — 프로필 (MyPageScreen).
/// 01-screens.md §7 스펙 기반. List/Form 네이티브 표준.
/// 로그아웃·회원 탈퇴는 프로필 카드로 진입하는 계정 화면(`AccountView`)에만 둔다.
struct ProfileView: View {
    @Environment(AuthSession.self) private var session
    @Environment(ThemeManager.self) private var themeManager

    @State private var showAppInfo    = false
    @State private var showSuggestion = false

    /// OCR 엔진 설정 (온디바이스 / Google / Naver) — OCRResultView와 공유.
    @AppStorage(OCREnginePreference.storageKey) private var ocrEngine: OCREnginePreference = .onDevice

    /// 알림 권한 상태 (설정 표시용).
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                // MARK: 사용자 정보 카드 → 계정 화면 진입 (iOS 설정 Apple ID 카드 문법)
                profileHeaderSection

                // MARK: 설정 섹션
                settingsSection

                // MARK: 지원 섹션
                supportSection
            }
            .navigationTitle("프로필")
            .task { await refreshNotificationStatus() }
            // 기능 제안 화면 push
            .navigationDestination(isPresented: $showSuggestion) {
                SuggestionView()
            }
            // 앱 정보 다이얼로그
            .alert("앱 정보", isPresented: $showAppInfo) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("Snippet\n버전 \(appVersion)\n\n표지 없이, 문장으로만 만나는 책\n\n© 2025 gowoobro")
            }
        }
    }

    // MARK: - 사용자 정보 섹션

    private var profileHeaderSection: some View {
        Section {
            if let user = session.currentUser {
                NavigationLink {
                    AccountView()
                } label: {
                    HStack(spacing: 16) {
                        // 원형 아바타 — 이름 첫 글자
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                            Text(String(user.name.prefix(1)))
                                .font(.title.weight(.semibold))
                                .foregroundStyle(Color.onAccent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(.title3.weight(.semibold))
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } footer: {
            Text("계정 관리는 프로필 카드를 눌러 진행하세요.")
        }
    }

    // MARK: - 설정 섹션

    private var settingsSection: some View {
        Section("설정") {
            // 테마 설정 — 시스템/라이트/다크 Picker
            @Bindable var tm = themeManager
            Picker(selection: $tm.mode) {
                ForEach(AppThemeMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            } label: {
                Label("테마 설정", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)

            // OCR 엔진 설정 — 온디바이스 / Google / Naver
            Picker(selection: $ocrEngine) {
                ForEach(OCREnginePreference.allCases) { engine in
                    Text(engine.label).tag(engine)
                }
            } label: {
                Label("OCR 엔진", systemImage: "text.viewfinder")
            }
            .pickerStyle(.menu)

            // 알림 설정 — 권한 상태 표시 + 요청/시스템 설정 이동
            Button {
                handleNotificationTap()
            } label: {
                HStack {
                    Label("알림", systemImage: "bell")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(notificationStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 지원 섹션

    private var supportSection: some View {
        Section {
            // 기능 제안
            Button {
                showSuggestion = true
            } label: {
                Label("기능 제안하기", systemImage: "lightbulb")
                    .foregroundStyle(.primary)
            }

            // 앱 정보
            Button {
                showAppInfo = true
            } label: {
                Label("앱 정보", systemImage: "info.circle")
                    .foregroundStyle(.primary)
            }
        } header: {
            Text("지원")
        } footer: {
            // 앱 아이덴티티 각주 — 어떤 앱의 몇 번째 버전인지 항상 확인 가능
            Text("Snippet 버전 \(appVersion)")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    // MARK: - 알림 설정

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "허용됨"
        case .denied: "꺼짐"
        default: "설정하기"
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    /// notDetermined → 권한 요청, 그 외 → 시스템 설정으로 이동.
    private func handleNotificationTap() {
        switch notificationStatus {
        case .notDetermined:
            Task {
                _ = await LocalNotifications.requestAuthorization()
                await refreshNotificationStatus()
            }
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - 헬퍼

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    ProfileView()
        .environment(AuthSession())
        .environment(ThemeManager())
}
