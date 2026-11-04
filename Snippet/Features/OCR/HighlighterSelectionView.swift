import SwiftUI

// MARK: - HighlighterSelectionView

/// 이미지 위를 드래그해 **수평 밑줄(Underline)** 을 여러 개 그어 OCR 영역을 지정하는 뷰.
///
/// Flutter `ImageHighlighterScreen`(`01-screens.md §4.6`)의 다중 영역 하이라이트를 SwiftUI로 이식.
/// 플로우:
///  - 이미지 위를 드래그하면 수평 밑줄 1개 = OCR 영역 1개가 추가된다.
///  - 밑줄을 탭하면 선택(파란 테두리)되고, 선택 영역을 삭제하거나 전체를 지울 수 있다.
///  - "OCR 실행 (N개)"은 각 밑줄 영역을 위→아래 순으로 OCR해 결합한다.
///  - "전체 인식"은 영역 무시하고 이미지 전체를 OCR한다.
struct HighlighterSelectionView: View {
    let image: UIImage
    /// 정규화(0~1, 좌상단 원점) 영역 배열로 OCR 실행
    let onRecognizeRegions: ([CGRect]) -> Void
    /// 이미지 전체 OCR 실행
    let onRecognizeAll: () -> Void

    /// 이미지 프레임 기준 정규화(0~1) 좌표 밑줄 목록 — 컨테이너 크기가 바뀌어도 이미지에 고정된다
    @State private var underlines: [Underline] = []
    /// 드래그 중 라이브 프리뷰 밑줄
    @State private var preview: Underline?
    /// 드래그 동안 누적된 포인트 (화면 표시 좌표)
    @State private var dragPoints: [CGPoint] = []
    /// 선택된 밑줄 id
    @State private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            guidanceBanner

            GeometryReader { geo in
                let frame = imageFrame(in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // 밑줄 + 프리뷰 렌더링
                    UnderlineLayer(underlines: underlines, preview: preview, frame: frame)
                        .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(frame: frame))
                .onTapGesture { location in
                    handleTap(at: location, frame: frame)
                }
            }
            .background(Color(.secondarySystemBackground))

            bottomBar
        }
    }

    // MARK: - 안내 배너

    private var guidanceBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentText)
                Text("손가락으로 텍스트에 밑줄을 그어주세요")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("• 자동으로 수평선으로 변환됩니다")
                Text("• 밑줄을 탭하면 선택·삭제할 수 있습니다")
            }
            .font(.caption)
            .foregroundStyle(Color.accentText)
            .padding(.leading, 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.accentColor.opacity(0.1))
    }

    // MARK: - 하단 버튼

    private var bottomBar: some View {
        VStack(spacing: 10) {
            // 선택/전체 삭제 컨트롤
            HStack(spacing: 16) {
                if selectedID != nil {
                    Button(role: .destructive) {
                        deleteSelected()
                    } label: {
                        Label("선택 밑줄 삭제", systemImage: "trash")
                    }
                } else if !underlines.isEmpty {
                    Button {
                        clearAll()
                    } label: {
                        Label("다시 그리기", systemImage: "arrow.counterclockwise")
                    }
                }
                Spacer()
                if !underlines.isEmpty {
                    Text("\(underlines.count)개 영역")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            HStack(spacing: 10) {
                Button {
                    onRecognizeAll()
                } label: {
                    Text("전체 인식")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    let regions = normalizedRegions()
                    guard !regions.isEmpty else { return }
                    onRecognizeRegions(regions)
                } label: {
                    Text("OCR 실행 (\(underlines.count)개)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.onAccent)
                .disabled(underlines.isEmpty)
            }
        }
        .padding(16)
    }

    // MARK: - 제스처

    private func dragGesture(frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragPoints.isEmpty {
                    selectedID = nil
                    setSelection(nil)
                }
                dragPoints.append(clamp(value.location, to: frame))
                if dragPoints.count >= 2 {
                    preview = Underline(points: dragPoints, in: frame)
                }
            }
            .onEnded { _ in
                if dragPoints.count >= 2 {
                    underlines.append(Underline(points: dragPoints, in: frame))
                }
                dragPoints = []
                preview = nil
            }
    }

    private func handleTap(at location: CGPoint, frame: CGRect) {
        // 위에 그려진(나중에 추가된) 밑줄부터 히트 테스트
        if let hit = underlines.reversed().first(where: { $0.rect(in: frame).contains(location) }) {
            selectedID = hit.id
            setSelection(hit.id)
        } else {
            selectedID = nil
            setSelection(nil)
        }
    }

    // MARK: - 밑줄 편집

    private func setSelection(_ id: UUID?) {
        underlines = underlines.map { var u = $0; u.isSelected = (u.id == id); return u }
    }

    private func deleteSelected() {
        guard let selectedID else { return }
        underlines.removeAll { $0.id == selectedID }
        self.selectedID = nil
    }

    private func clearAll() {
        underlines.removeAll()
        dragPoints = []
        preview = nil
        selectedID = nil
    }

    // MARK: - 정규화 좌표 변환

    /// 각 밑줄을 표시 이미지 프레임 기준 좌상단 원점 정규화(0~1) 사각형으로 반환.
    private func normalizedRegions() -> [CGRect] {
        underlines.map { $0.normalizedRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)) }
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

// MARK: - Underline 모델

/// 이미지 프레임 기준 정규화(0~1, 좌상단 원점) 좌표로 저장되는 수평 밑줄.
/// 폴드/언폴드 등으로 컨테이너가 리사이즈돼도 이미지 위 같은 위치를 유지한다.
private struct Underline: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let endX: CGFloat
    /// 밑줄 중심 Y (드래그 포인트 평균)
    let centerY: CGFloat
    /// 밑줄(영역) 높이
    let height: CGFloat
    var isSelected: Bool = false

    /// 화면 표시 좌표의 드래그 포인트 묶음으로부터 수평 밑줄 생성.
    /// Flutter `_convertToStraightLine` 규칙 이식: minX..maxX, 평균 Y, height = clamp((maxY-minY)*3, 40, 80).
    init(points: [CGPoint], in frame: CGRect) {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let yRange = (ys.max() ?? 0) - (ys.min() ?? 0)
        let w = max(frame.width, 1)
        let h = max(frame.height, 1)
        startX = ((xs.min() ?? 0) - frame.minX) / w
        endX = ((xs.max() ?? 0) - frame.minX) / w
        centerY = (ys.reduce(0, +) / CGFloat(max(points.count, 1)) - frame.minY) / h
        height = min(max(yRange * 3, 40), 80) / h
    }

    /// 정규화 영역 사각형 (OCR 영역)
    var normalizedRect: CGRect {
        CGRect(
            x: min(startX, endX),
            y: centerY - height / 2,
            width: abs(endX - startX),
            height: height
        )
    }

    /// 현재 이미지 프레임 기준 화면 표시 사각형 (히트 테스트 + 렌더링)
    func rect(in frame: CGRect) -> CGRect {
        let r = normalizedRect
        return CGRect(
            x: frame.minX + r.minX * frame.width,
            y: frame.minY + r.minY * frame.height,
            width: r.width * frame.width,
            height: r.height * frame.height
        )
    }

    /// 현재 이미지 프레임 기준 중앙선 양 끝점
    func line(in frame: CGRect) -> (CGPoint, CGPoint) {
        let y = frame.minY + centerY * frame.height
        return (
            CGPoint(x: frame.minX + startX * frame.width, y: y),
            CGPoint(x: frame.minX + endX * frame.width, y: y)
        )
    }
}

// MARK: - UnderlineLayer (렌더링)

/// 밑줄 배경(반투명 노랑) + 중앙 두꺼운 노란 선 + 선택 시 파란 테두리 렌더링.
/// Flutter `UnderlinePainter` 이식.
private struct UnderlineLayer: View {
    let underlines: [Underline]
    let preview: Underline?
    /// 표시 이미지 프레임 (정규화 좌표 → 화면 좌표 변환용)
    let frame: CGRect

    var body: some View {
        Canvas { context, _ in
            var all = underlines
            if let preview { all.append(preview) }

            for u in all {
                let rect = u.rect(in: frame)
                let path = Path(rect)

                // 1. 배경 반투명 노랑
                context.fill(path, with: .color(Color.yellow.opacity(0.2)))

                // 2. 중앙 수평 두꺼운 노란 선
                let (start, end) = u.line(in: frame)
                var line = Path()
                line.move(to: start)
                line.addLine(to: end)
                context.stroke(
                    line,
                    with: .color(Color.yellow),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

                // 3. 선택 시 파란 테두리
                if u.isSelected {
                    context.stroke(path, with: .color(Color.blue), lineWidth: 2)
                }
            }
        }
    }
}
