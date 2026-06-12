import SwiftUI
import UIKit

// MARK: - ActivityShareSheet

/// UIActivityViewController를 SwiftUI에서 사용하기 위한 래퍼.
///
/// iPad에서 popover로 표시되므로 `sourceRect` 파라미터를 전달해야 한다.
struct ActivityShareSheet: UIViewControllerRepresentable {

    let activityItems: [Any]
    var sourceRect: CGRect = .zero

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        // iPad popover anchor
        if let popover = vc.popoverPresentationController {
            popover.sourceRect = sourceRect.isEmpty
                ? CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 1, height: 1)
                : sourceRect
            popover.permittedArrowDirections = .any
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View+ShareImage

extension View {

    /// 공유 카드 렌더링 후 시스템 공유 시트를 표시하는 편의 메서드.
    ///
    /// - Parameters:
    ///   - isPresented: 시트 표시 바인딩.
    ///   - mode: 공유 카드 콘텐츠 모드.
    ///   - background: 공유 카드 배경.
    ///   - sourceRect: iPad용 popover anchor rect.
    func shareCard(
        isPresented: Binding<Bool>,
        mode: ShareCardMode,
        background: ShareCardBackground,
        sourceRect: CGRect = .zero
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            ShareCardSheetView(
                mode: mode,
                background: background,
                sourceRect: sourceRect,
                onDismiss: { isPresented.wrappedValue = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - ShareCardSheetView (내부 — 렌더링 진행 표시용)

private struct ShareCardSheetView: View {

    let mode: ShareCardMode
    let background: ShareCardBackground
    let sourceRect: CGRect
    let onDismiss: () -> Void

    @State private var isRendering = false
    @State private var showShare = false
    @State private var renderedURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            if isRendering {
                ProgressView("공유 이미지 생성 중...")
            } else {
                Text("공유하기")
                    .font(.headline)

                Button {
                    renderAndShare()
                } label: {
                    Label("이미지로 공유", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Button("취소", role: .cancel) {
                    onDismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 24)
        .sheet(isPresented: $showShare) {
            if let url = renderedURL {
                ActivityShareSheet(activityItems: [url], sourceRect: sourceRect)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: showShare) { _, newValue in
            // 공유 시트 닫히면 이 시트도 닫기
            if !newValue { onDismiss() }
        }
    }

    private func renderAndShare() {
        isRendering = true
        Task { @MainActor in
            guard let image = ShareCardRenderer.render(mode: mode, background: background),
                  let url = ShareCardRenderer.saveTempPNG(image) else {
                isRendering = false
                return
            }
            renderedURL = url
            isRendering = false
            showShare = true
        }
    }
}
