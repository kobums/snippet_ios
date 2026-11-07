import SwiftUI

// MARK: - 읽기 폭

/// 넓은 화면(iPhone Duo 안쪽 화면, iPad)에서 목록·카드가 화면 끝까지 늘어나 읽기 어려워지지 않도록
/// 콘텐츠 폭을 제한한다. 폰처럼 이보다 좁은 화면에서는 아무 영향이 없다.
enum ReadableLayout {
    static let maxWidth: CGFloat = 720
}

private struct ReadableContentMargins: ViewModifier {
    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // 넘치는 폭만큼만 좌우 여백 — 폰에선 0이라 plain List·ScrollView의 기본값과 같다
            .contentMargins(.horizontal, max(0, (containerWidth - ReadableLayout.maxWidth) / 2), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
    }
}

extension View {
    /// plain List의 행들을 읽기 폭 안 가운데로 — 넘치는 폭만큼 좌우 contentMargins.
    /// ScrollView 안 콘텐츠에는 상태 없이 동작하는 `readableWidth()`를 쓴다.
    /// insetGrouped List에는 쓰지 않는다 — 기본 좌우 여백을 덮어쓴다.
    func readableContentMargins() -> some View {
        modifier(ReadableContentMargins())
    }

    /// 뷰를 읽기 폭 안 가운데로 — ScrollView 안 콘텐츠 스택, 스크롤 밖 고정 요소(검색창·필터 바)에 쓴다.
    func readableWidth() -> some View {
        frame(maxWidth: ReadableLayout.maxWidth).frame(maxWidth: .infinity)
    }
}
