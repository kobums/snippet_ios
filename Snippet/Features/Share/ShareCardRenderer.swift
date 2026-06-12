import SwiftUI

// MARK: - ShareCardRenderer

/// `ShareCardView`를 UIImage로 렌더링하는 헬퍼.
///
/// iOS 16+ `ImageRenderer`를 사용하며 scale 3.0으로 렌더링해
/// 1080×1350 픽셀(Instagram 4:5 피드 사이즈)을 생성한다.
@MainActor
enum ShareCardRenderer {

    /// 공유 카드를 UIImage로 렌더링한다.
    /// - Parameters:
    ///   - mode: 카드 콘텐츠 모드 (session / snippet).
    ///   - background: 배경 타입 (gradient / coverImage / photo).
    /// - Returns: 렌더링된 UIImage. 실패 시 nil.
    static func render(
        mode: ShareCardMode,
        background: ShareCardBackground
    ) -> UIImage? {
        let card = ShareCardView(mode: mode, background: background)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0   // 3x → 1080×1350 px
        return renderer.uiImage
    }

    /// 렌더링된 UIImage를 temp 디렉토리에 PNG 파일로 저장한 뒤 URL을 반환한다.
    /// - Parameter image: 저장할 UIImage.
    /// - Returns: 저장 파일 URL. 실패 시 nil.
    static func saveTempPNG(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let ts = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("share_\(ts).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
