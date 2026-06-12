import SwiftUI

// MARK: - OCRResultView

/// OCR 영역 선택 → 인식 → 편집·확정 화면 (01-screens.md §4.6~4.7 기반).
///
/// 플로우:
///  1. 영역 선택(selecting): 이미지 위를 드래그해 인식할 문장 영역을 지정하거나 "전체 인식" 선택
///  2. 인식(processing): 선택 영역(또는 전체)을 Vision OCR
///  3. 결과(result): 인식 텍스트를 편집 후 "이 텍스트 사용"
struct OCRResultView: View {

    let image: UIImage
    /// OCR 완료 후 텍스트를 호출자에 전달하는 콜백
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case selecting
        case processing
        case result
        case error(String)
    }

    @State private var phase: Phase = .selecting
    @State private var recognizedText: String = ""

    private let recognizer = TextRecognizer()

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .selecting:
                    RegionSelectionView(
                        image: image,
                        onRecognizeRegion: { region in recognize(region: region) },
                        onRecognizeAll: { recognize(region: nil) }
                    )
                case .processing:
                    processingView
                case .error(let message):
                    errorView(message: message)
                case .result:
                    resultEditor
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                if phase == .result {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("이 텍스트 사용") {
                            onConfirm(recognizedText)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch phase {
        case .selecting: return "인식할 영역 선택"
        default: return "텍스트 인식 결과"
        }
    }

    // MARK: - Subviews

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("텍스트를 인식하는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("영역 다시 선택") {
                phase = .selecting
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 안내 배너
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("인식된 텍스트를 수정한 후 '이 텍스트 사용'을 누르세요.")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))

            TextEditor(text: $recognizedText)
                .padding(12)
                .font(.body)

            // 하단 버튼 영역
            VStack(spacing: 10) {
                Button {
                    phase = .selecting
                } label: {
                    Label("영역 다시 선택", systemImage: "crop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onConfirm(recognizedText)
                    dismiss()
                } label: {
                    Text("이 텍스트 사용")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
    }

    // MARK: - OCR

    private func recognize(region: CGRect?) {
        phase = .processing
        Task {
            do {
                let text = try await recognizer.recognize(image: image, region: region)
                await MainActor.run {
                    if text.isEmpty {
                        phase = .error("선택한 영역에서 텍스트를 인식하지 못했습니다.\n영역을 다시 지정해주세요.")
                    } else {
                        recognizedText = text
                        phase = .result
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .error("텍스트 인식 중 오류가 발생했습니다.\n\(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - RegionSelectionView

/// 이미지 위를 드래그해 인식 영역을 지정하는 뷰.
/// 표시된 이미지(aspect-fit) 프레임 기준 좌상단 원점 정규화 사각형을 콜백한다.
private struct RegionSelectionView: View {
    let image: UIImage
    let onRecognizeRegion: (CGRect) -> Void
    let onRecognizeAll: () -> Void

    @State private var dragStart: CGPoint?
    @State private var selection: CGRect = .zero
    /// 표시 이미지 프레임 기준 좌상단 원점 정규화(0~1) 선택 영역
    @State private var normalized: CGRect = .zero

    private var hasSelection: Bool {
        selection.width > 12 && selection.height > 12
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let frame = imageFrame(in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // 선택 영역 외부 디밍 + 테두리
                    if hasSelection {
                        Rectangle()
                            .fill(Color.black.opacity(0.45))
                            .mask {
                                Rectangle()
                                    .overlay {
                                        Rectangle()
                                            .frame(width: selection.width, height: selection.height)
                                            .position(x: selection.midX, y: selection.midY)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                            }
                            .allowsHitTesting(false)

                        Rectangle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: selection.width, height: selection.height)
                            .position(x: selection.midX, y: selection.midY)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = dragStart ?? clamp(value.startLocation, to: frame)
                            dragStart = start
                            let current = clamp(value.location, to: frame)
                            let rect = CGRect(
                                x: min(start.x, current.x),
                                y: min(start.y, current.y),
                                width: abs(current.x - start.x),
                                height: abs(current.y - start.y)
                            )
                            selection = rect
                            // 이미지 프레임 기준 좌상단 원점 정규화 (0~1)
                            normalized = CGRect(
                                x: (rect.minX - frame.minX) / frame.width,
                                y: (rect.minY - frame.minY) / frame.height,
                                width: rect.width / frame.width,
                                height: rect.height / frame.height
                            )
                        }
                        .onEnded { _ in
                            dragStart = nil
                        }
                )
            }
            .background(Color(.secondarySystemBackground))

            // 안내 + 버튼
            VStack(spacing: 10) {
                Text(hasSelection ? "선택한 영역만 인식합니다" : "인식할 문장을 드래그해 선택하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 10) {
                    Button {
                        onRecognizeAll()
                    } label: {
                        Text("전체 인식")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        guard hasSelection else { return }
                        onRecognizeRegion(normalized)
                    } label: {
                        Text("선택 영역 인식")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasSelection)
                }
            }
            .padding(16)
        }
    }

    /// 컨테이너 크기 안에서 이미지가 aspect-fit으로 표시되는 실제 사각형
    private func imageFrame(in container: CGSize) -> CGRect {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - displaySize.width) / 2,
            y: (container.height - displaySize.height) / 2,
            width: displaySize.width,
            height: displaySize.height
        )
    }

    private func clamp(_ point: CGPoint, to frame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, frame.minX), frame.maxX),
            y: min(max(point.y, frame.minY), frame.maxY)
        )
    }
}
