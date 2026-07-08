import SwiftUI

/// 빈 상태 뷰: 아이콘 + 타이틀 + 설명 + 선택적 액션 버튼.
/// 시스템 `ContentUnavailableView` 래퍼 (iOS 17+).
struct EmptyStateView: View {

    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.onAccent)
                    .tint(.primary)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        systemImage: "books.vertical",
        title: "서재가 비어 있어요",
        message: "첫 번째 책을 추가해보세요.",
        actionTitle: "책 추가",
        action: {}
    )
}
