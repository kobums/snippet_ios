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

    /// 사용자가 선택한 OCR 엔진 (온디바이스 / Google / Naver). 프로필 설정과 공유.
    @AppStorage(OCREnginePreference.storageKey) private var enginePref: OCREnginePreference = .onDevice

    private let recognizer = TextRecognizer()
    private let ocrService = OCRService()

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .selecting:
                    HighlighterSelectionView(
                        image: image,
                        onRecognizeRegions: { regions in recognize(regions: regions) },
                        onRecognizeAll: { recognize(regions: []) }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                if phase == .result {
                    ToolbarItem(placement: .confirmationAction) {
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
                .foregroundStyle(Color.onAccent)
                .disabled(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
    }

    // MARK: - OCR

    /// 영역 배열로 OCR 실행. 빈 배열이면 전체 이미지 인식.
    /// 엔진 설정에 따라 온디바이스(Vision) 또는 백엔드(Google/Naver) 경로를 사용한다.
    private func recognize(regions: [CGRect]) {
        phase = .processing
        Task {
            do {
                let text: String
                if let backendEngine = enginePref.backendEngine {
                    text = try await recognizeOnServer(regions: regions, engine: backendEngine)
                } else {
                    text = try await recognizer.recognize(image: image, regions: regions)
                }
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

    /// 백엔드 OCR(`POST /ocr/extract`). 정규화 영역(0~1)을 이미지 픽셀 좌표로 변환해 전송.
    private func recognizeOnServer(regions: [CGRect], engine: OcrEngine) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            return ""
        }
        // 픽셀 좌표 = 정규화 × (포인트 크기 × scale)
        let pxW = Double(image.size.width * image.scale)
        let pxH = Double(image.size.height * image.scale)
        let pixelRegions: [OcrRegion]? = regions.isEmpty ? nil : regions.map { r in
            OcrRegion(
                left: Double(r.minX) * pxW,
                top: Double(r.minY) * pxH,
                right: Double(r.maxX) * pxW,
                bottom: Double(r.maxY) * pxH
            )
        }
        let response = try await ocrService.extract(imageData: data, engine: engine, regions: pixelRegions)
        return response.extractedText
    }
}
