import Foundation

/// OCR 엔진 사용자 설정.
///
/// Flutter 앱의 "OCR 엔진 선택"(Google/Naver) 재현 + 네이티브 온디바이스(Vision) 옵션 추가.
/// `@AppStorage(OCREnginePreference.storageKey)`로 ProfileView(설정)·OCRResultView(인식)에서 공유.
enum OCREnginePreference: String, CaseIterable, Identifiable, Sendable {
    /// 온디바이스 Apple Vision (네트워크 불필요, 기본값)
    case onDevice
    /// 백엔드 Google Cloud Vision
    case google
    /// 백엔드 Naver Clova
    case naver

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onDevice: "온디바이스 (기본)"
        case .google:   "Google Vision (정확도)"
        case .naver:    "Naver Clova (한글 특화)"
        }
    }

    /// 백엔드 엔진 값 (온디바이스면 nil).
    var backendEngine: OcrEngine? {
        switch self {
        case .onDevice: nil
        case .google:   .google
        case .naver:    .naver
        }
    }

    /// `@AppStorage` 키 (UserDefaults 공유).
    static let storageKey = "ocr_engine_preference"
}
