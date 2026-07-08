import SwiftUI

// MARK: - SnippetTabView

/// 스니펫 탭 루트 — 상단 세그먼트로 스와이프/보관함 서브탭 전환.
struct SnippetTabView: View {

    @State private var vm = SnippetViewModel()
    @State private var selectedSubTab: SubTab = .swipe

    enum SubTab: Int, CaseIterable {
        case swipe
        case archive

        var title: String {
            switch self {
            case .swipe: "스와이프"
            case .archive: "보관함"
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top + 76
                let bottomInset = proxy.safeAreaInsets.bottom + 8

                ZStack(alignment: .top) {
                    ZStack {
                        // 주의: contentMargins를 ZStack 전체에 걸면 카드 안 인용문
                        // ScrollView에도 전파되어 문장 위아래에 빈 공간이 생긴다.
                        SnippetSwipeView(vm: vm)
                            .padding(.top, topInset)
                            .padding(.bottom, bottomInset)
                            .opacity(selectedSubTab == .swipe ? 1 : 0)
                            .allowsHitTesting(selectedSubTab == .swipe)

                        ArchiveView(vm: vm)
                            .contentMargins(.top, topInset, for: .scrollContent)
                            .contentMargins(.bottom, bottomInset, for: .scrollContent)
                            .opacity(selectedSubTab == .archive ? 1 : 0)
                            .allowsHitTesting(selectedSubTab == .archive)
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
                    .ignoresSafeArea(edges: [.top, .bottom])

                    // 플로팅 서브탭 바
                    FloatingSubTabBar(
                        tabs: SubTab.allCases.map { ($0, $0.title) },
                        selection: $selectedSubTab
                    )
                    .padding(.top, 4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    SnippetTabView()
}
