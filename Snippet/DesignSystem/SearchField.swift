import SwiftUI

/// 공용 검색 필드 — 플로팅 바·하단 탭바와 같은 리퀴드 글래스 캡슐.
///
/// - 캡슐 전체가 탭 영역: 어디를 눌러도 입력이 시작된다.
/// - 포커스되면 시스템 검색처럼 '취소' 버튼이 오른쪽에서 슬라이드해 들어오고,
///   해제되면 같은 경로로 나간다(공간 일관성).
/// - 지우기(xmark) 버튼은 텍스트가 생길 때만 스프링으로 나타난다.
///
/// 화면 안 인라인 필터링에 사용한다. 내비게이션 바 검색은 시스템 `.searchable`을 그대로 쓸 것.
struct SearchField: View {

    let prompt: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            field

            if isFocused {
                Button("취소") {
                    text = ""
                    isFocused = false
                }
                .font(.subheadline)
                .foregroundStyle(Color.accentText)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 1.0), value: isFocused)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(isFocused ? AnyShapeStyle(Color.accentText) : AnyShapeStyle(.secondary))

            TextField(prompt, text: $text)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    Haptics.light()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        // glassEffect를 필드에 직접 걸면 터치를 삼키므로 배경 레이어에만 적용.
        .background {
            Color.clear
                .glassEffect(.regular, in: Capsule())
                .allowsHitTesting(false)
        }
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
        .animation(.spring(response: 0.3, dampingFraction: 1.0), value: text.isEmpty)
        .animation(.smooth(duration: 0.2), value: isFocused)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var text = ""
        var body: some View {
            VStack(spacing: 20) {
                SearchField(prompt: "제목이나 저자로 검색", text: $text)
            }
            .padding()
        }
    }
    return PreviewHost()
}
