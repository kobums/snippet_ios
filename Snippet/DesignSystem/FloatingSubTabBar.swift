import SwiftUI

/// 하단 탭바(bottom navigation)와 같은 문법의 플로팅 서브탭 바.
/// 글래스 캡슐 안에 탭 버튼들이 있고, 선택 항목에 은은한 하이라이트 필이 슬라이드한다.
struct FloatingSubTabBar<Tab: Hashable>: View {

    let tabs: [(tab: Tab, title: String)]
    @Binding var selection: Tab
    /// 좁은 공간용 컴팩트 모드 (작은 폰트·패딩).
    var compact: Bool = false

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.tab) { item in
                Button {
                    selection = item.tab
                } label: {
                    Text(item.title)
                        .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(
                            selection == item.tab
                                ? AnyShapeStyle(Color.accentText)
                                : AnyShapeStyle(.secondary)
                        )
                        .padding(.horizontal, compact ? 8 : 12)
                        .padding(.vertical, compact ? 8 : 10)
                        .background {
                            // 시스템 하단 탭바처럼 은은한 하이라이트 필
                            if selection == item.tab {
                                Capsule()
                                    .fill(Color.primary.opacity(0.1))
                                    .matchedGeometryEffect(id: "pill", in: pillNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .padding(4)
        // glassEffect를 버튼 컨테이너에 직접 걸면 터치를 삼키므로,
        // 터치를 받지 않는 배경 레이어에만 적용해 하단 탭바와 같은 리퀴드 글래스 룩을 낸다.
        .background {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .allowsHitTesting(false)
        }
    }
}
