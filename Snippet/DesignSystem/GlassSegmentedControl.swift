import SwiftUI

/// 풀-너비 글래스 세그먼트 컨트롤.
/// `FloatingSubTabBar`(내재 폭)의 등폭(segment) 버전 — 같은 리퀴드 글래스 캡슐 안에서
/// 선택 하이라이트 필이 스프링으로 슬라이드하고, 선택 변경 시 selection 햅틱이 울린다.
/// 시스템 `.segmented` 피커를 대체해 앱의 플로팅 크롬과 재질을 통일한다.
struct GlassSegmentedControl<Value: Hashable>: View {

    let segments: [(value: Value, title: String)]
    @Binding var selection: Value
    /// 세그먼트별 카운트 뱃지 — nil이면 표시하지 않는다.
    var count: ((Value) -> Int)? = nil

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments, id: \.value) { segment in
                let isSelected = selection == segment.value
                Button {
                    guard !isSelected else { return }
                    Haptics.selection()
                    selection = segment.value
                } label: {
                    HStack(spacing: 5) {
                        Text(segment.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                isSelected
                                    ? AnyShapeStyle(Color.accentText)
                                    : AnyShapeStyle(.secondary)
                            )

                        if let count {
                            let n = count(segment.value)
                            if n > 0 {
                                Text("\(n)")
                                    .font(.footnote.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(.tertiary)
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected {
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
        // glassEffect를 버튼 컨테이너에 직접 걸면 터치를 삼키므로 배경 레이어에만 적용.
        .background {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var selection = "a"
        var body: some View {
            GlassSegmentedControl(
                segments: [("a", "스니펫"), ("b", "독서일기"), ("c", "리뷰")],
                selection: $selection
            )
            .padding()
        }
    }
    return PreviewHost()
}
