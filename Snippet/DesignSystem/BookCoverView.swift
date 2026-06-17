import SwiftUI

/// 책 표지 비동기 이미지 + 플레이스홀더.
///
/// 표지 치수(03-design-system.md §3.5)를 사이즈 프리셋으로 제공:
/// small 45×68(r6) / medium 50×75(r8) / large 60×90(r8) / header 72×100(r8)
struct BookCoverView: View {

    enum CoverSize {
        case small
        case medium
        case large
        case header
        case custom(width: CGFloat, height: CGFloat, cornerRadius: CGFloat)

        var width: CGFloat {
            switch self {
            case .small: 45
            case .medium: 50
            case .large: 60
            case .header: 72
            case .custom(let width, _, _): width
            }
        }

        var height: CGFloat {
            switch self {
            case .small: 68
            case .medium: 75
            case .large: 90
            case .header: 100
            case .custom(_, let height, _): height
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: AppRadius.coverSmall
            case .medium, .large, .header: AppRadius.card
            case .custom(_, _, let cornerRadius): cornerRadius
            }
        }
    }

    let url: URL?
    var size: CoverSize = .medium
    var showsShadow: Bool = true

    /// URL 문자열 편의 이니셜라이저 (빈 문자열은 nil 처리).
    init(urlString: String?, size: CoverSize = .medium, showsShadow: Bool = true) {
        self.url = urlString.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        self.size = size
        self.showsShadow = showsShadow
    }

    init(url: URL?, size: CoverSize = .medium, showsShadow: Bool = true) {
        self.url = url
        self.size = size
        self.showsShadow = showsShadow
    }

    var body: some View {
        let cover = AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                placeholder
            }
        }

        // width가 .infinity(예: 서재 그리드 카드)일 때 .frame(width: .infinity)는
        // 레이아웃을 NaN으로 만들어 clipShape에서 "CALayer position NaN" 크래시(SIGABRT)를 유발한다.
        // 무한대 폭은 maxWidth로 처리해 부모 폭을 채우도록 한다.
        return Group {
            if size.width.isFinite {
                cover.frame(width: size.width, height: size.height)
            } else {
                cover.frame(maxWidth: .infinity).frame(height: size.height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        .shadow(
            color: showsShadow ? .black.opacity(0.08) : .clear,
            radius: 6,
            x: 0,
            y: 2
        )
    }

    private var placeholder: some View {
        // 무한대 폭일 때 아이콘 크기가 NaN/무한대가 되지 않도록 유한 폭으로 보정.
        let iconBase = size.width.isFinite ? size.width : 100
        return ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "book.closed")
                .font(.system(size: iconBase * 0.4))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        BookCoverView(url: nil, size: .small)
        BookCoverView(url: nil, size: .medium)
        BookCoverView(url: nil, size: .large)
        BookCoverView(url: nil, size: .header)
    }
    .padding()
}
