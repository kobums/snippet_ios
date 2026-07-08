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
            Tab(value: SnippetTab.snippet) {
                SnippetTabView()
            } label: {
                tabLabel("스니펫", outline: "quote.bubble", fill: "quote.bubble.fill", tab: .snippet)
            }

            Tab(value: SnippetTab.dashboard) {
                DashboardTabView()
            } label: {
                tabLabel("대시보드", outline: "chart.bar", fill: "chart.bar.fill", tab: .dashboard)
            }

            Tab(value: SnippetTab.records) {
                RecordsTabView()
            } label: {
                tabLabel("독서기록", outline: "doc.text", fill: "doc.text.fill", tab: .records)
            }

            Tab(value: SnippetTab.library) {
                LibraryTabView()
            } label: {
                tabLabel("서재", outline: "books.vertical", fill: "books.vertical.fill", tab: .library)
            }

            Tab(value: SnippetTab.profile) {
                ProfileView()
            } label: {
                tabLabel("프로필", outline: "person", fill: "person.fill", tab: .profile)
            }
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

    /// 탭바 라벨 — 선택된 탭은 채워진(fill) 심벌, 미선택은 아웃라인 심벌.
    /// 탭바의 자동 fill 변형을 끄기 위해 symbolVariants를 .none으로 고정한다.
    private func tabLabel(_ title: String, outline: String, fill: String, tab: SnippetTab) -> some View {
        Label(title, systemImage: selectedTab == tab ? fill : outline)
            .environment(\.symbolVariants, .none)
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
