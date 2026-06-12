import Vision
import UIKit

// MARK: - TextRecognizer

/// Apple Vision 프레임워크(VNRecognizeTextRequest)를 사용한 온디바이스 OCR.
///
/// 현재 구현: 전체 이미지를 한 번 OCR하여 텍스트 전체를 반환.
///
/// NOTE: Flutter 원본(`04-platform.md §3`)의 제품 플로우는 서버 OCR(백엔드 `/ocr/extract` 멀티파트)이다.
/// 이 클래스는 외부 SDK·네트워크 없이 온디바이스로 동작하는 대안 구현이며,
/// 밑줄 하이라이터(`ImageHighlighterScreen` 스펙, `01-screens.md §4.6`)의
/// "영역 선택 → 해당 영역만 OCR" 기능은 단순화하여 전체 OCR + 결과 텍스트 편집으로 대체했다.
/// 영역 선택 UX를 재현하려면 UIImage를 `cgImage?.cropping(to:)`로 잘라 Recognition 재실행하면 된다.
@MainActor
final class TextRecognizer {

    // MARK: - Public API

    /// UIImage를 Vision으로 인식하여 텍스트 문자열을 반환한다.
    /// - Parameters:
    ///   - image: 카메라 촬영 또는 갤러리 선택 이미지
    ///   - region: 인식할 영역(정규화 좌표, **좌상단 원점** 0~1). nil이면 전체 인식.
    ///             호출 측은 화면에 표시된 이미지 기준으로 좌상단 원점 사각형을 넘기면 되고,
    ///             Vision의 좌하단 원점 변환은 내부에서 처리한다.
    /// - Returns: 줄바꿈 결합된 인식 텍스트 (실패 시 빈 문자열)
    nonisolated func recognize(image: UIImage, region: CGRect? = nil) async throws -> String {
        // 표시 이미지와 OCR 픽셀 좌표를 일치시키기 위해 업라이트(.up)로 정규화한다.
        guard let cgImage = image.uprightImage().cgImage else {
            throw TextRecognizerError.invalidImage
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            // 한국어 + 영어, 최고 정확도 레벨
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // 좌상단 원점(0~1) → Vision 좌하단 원점 ROI로 변환
            if let region {
                let flipped = CGRect(
                    x: region.minX,
                    y: 1 - region.maxY,
                    width: region.width,
                    height: region.height
                )
                let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
                request.regionOfInterest = flipped.intersection(unit)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - UIImage Orientation Normalization

private extension UIImage {
    /// 이미지를 .up 방향으로 다시 그려 픽셀 좌표와 표시 좌표를 일치시킨다.
    func uprightImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Error

enum TextRecognizerError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 처리할 수 없습니다."
        }
    }
}
