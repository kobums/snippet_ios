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
            VStack(spacing: 0) {
                // 서브탭 세그먼트
                Picker("탭", selection: $selectedSubTab) {
                    ForEach(SubTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                Divider()

                // 탭 콘텐츠
                TabView(selection: $selectedSubTab) {
                    SnippetSwipeView(vm: vm)
                        .tag(SubTab.swipe)

                    ArchiveView(vm: vm)
                        .tag(SubTab.archive)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
            }
            .navigationTitle("SNIPPET")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SNIPPET")
                        .brandWordmarkStyle()
                }
            }
        }
    }
}

#Preview {
    SnippetTabView()
}
