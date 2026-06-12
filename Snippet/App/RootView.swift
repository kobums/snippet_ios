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
    }
}

#Preview {
    RootView()
        .environment(AuthSession())
}
