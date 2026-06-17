import SwiftUI

enum SnippetTab: Hashable {
    case snippet
    case dashboard
    case records
    case library
    case profile
}

struct RootView: View {
    @State private var selectedTab: SnippetTab = .snippet
    /// 앱 전역 테마 매니저 — RootView에서 1개 생성, environment 주입.
    @State private var themeManager = ThemeManager()
    /// 푸시 딥링크 라우터 — pendingTab 변화를 관찰해 탭 전환.
    private let deepLinkRouter = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            SnippetTabView()
                .tabItem { Label("스니펫", systemImage: "sparkles") }
                .tag(SnippetTab.snippet)

            DashboardTabView()
                .tabItem { Label("대시보드", systemImage: "chart.bar") }
                .tag(SnippetTab.dashboard)

            RecordsTabView()
                .tabItem { Label("독서기록", systemImage: "square.and.pencil") }
                .tag(SnippetTab.records)

            LibraryTabView()
                .tabItem { Label("서재", systemImage: "books.vertical") }
                .tag(SnippetTab.library)

            ProfileView()
                .tabItem { Label("프로필", systemImage: "person") }
                .tag(SnippetTab.profile)
        }
        .preferredColorScheme(themeManager.colorScheme)
        .environment(themeManager)
        // 앱 실행 중 알림 탭 → pendingTab 변화 감지해 즉시 전환.
        .onChange(of: deepLinkRouter.pendingTab) { _, newValue in
            consumePendingTab(newValue)
        }
        // 콜드 스타트(종료 상태에서 알림 탭으로 실행) → RootView 등장 시 보관된 탭 소비.
        .task {
            consumePendingTab(deepLinkRouter.pendingTab)
        }
    }

    /// pendingTab이 있으면 selectedTab으로 반영하고 라우터를 비운다.
    private func consumePendingTab(_ tab: SnippetTab?) {
        guard let tab else { return }
        selectedTab = tab
        deepLinkRouter.pendingTab = nil
    }
}

#Preview {
    RootView()
        .environment(AuthSession())
}
