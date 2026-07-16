import SwiftUI

/// 커스텀 배경 버튼용 눌림 피드백 스타일.
/// 터치 다운 즉시 살짝 축소되고, 떼면 스프링으로 복귀한다(critically damped — 오버슈트 없음).
/// 시스템 스타일(.glass, .bordered 등)이 자체 피드백을 제공하지 않는
/// `.plain` + 커스텀 배경 조합에서만 사용.
struct PressableButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 1.0), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// 눌림 시 즉시 축소 피드백을 주는 버튼 스타일.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
