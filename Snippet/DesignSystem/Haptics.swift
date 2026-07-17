import UIKit

/// 햅틱 피드백 헬퍼.
///
/// 문서 사용처(03-design-system.md):
/// - pull-to-refresh: `Haptics.medium()`
/// - 스와이프 판정(Like/Pass): `Haptics.medium()` 또는 `Haptics.success()`
/// - 별점/피커 선택: `Haptics.selection()`
/// - 삭제/에러: `Haptics.error()`
enum Haptics {

    // MARK: Impact

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func light() { impact(.light) }
    static func medium() { impact(.medium) }
    static func heavy() { impact(.heavy) }
    static func soft() { impact(.soft) }
    static func rigid() { impact(.rigid) }

    // MARK: Selection

    /// 피커·세그먼트·별점 등 선택 변경.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Notification

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// 비동기 작업 결과를 그대로 알릴 때 — 성공/실패 분기를 호출부마다 반복하지 않는다.
    static func notify(success: Bool) {
        success ? Haptics.success() : Haptics.error()
    }
}
