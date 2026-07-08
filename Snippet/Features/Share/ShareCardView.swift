import SwiftUI

// MARK: - ShareCardMode

/// 공유 카드에 표시할 콘텐츠 모드.
enum ShareCardMode {
    /// 세션 완료 카드: 독서 시간 / 읽은 페이지 / 페이스 + 책 제목·저자
    case session(
        elapsedText: String,
        pagesRead: Int,
        pace: Double,
        bookTitle: String,
        bookAuthor: String,
        showBookTitle: Bool
    )
    /// 스니펫 공유 카드: 인용 문장 + 책 제목·저자
    case snippet(
        text: String,
        tag: String?,
        bookTitle: String,
        bookAuthor: String
    )
}

// MARK: - ShareCardBackground

/// 공유 카드 배경 타입.
enum ShareCardBackground {
    case gradient           // 기본 앱 그라데이션
    case coverImage(UIImage) // 책 표지 이미지
    case photo(UIImage)     // 사용자 갤러리/카메라 사진
}

// MARK: - ShareCardView

/// SNS 공유용 카드 뷰 (1080×1350, Instagram 4:5 비율).
///
/// `ShareCardRenderer`로 UIImage 렌더링 시 이 뷰를 사용.
/// 배경 3모드: gradient / coverImage / photo. 텍스트는 항상 흰색(배경이 있을 때)
/// 또는 primary(gradient 기본).
struct ShareCardView: View {

    let mode: ShareCardMode
    let background: ShareCardBackground

    // 렌더링용 고정 크기 (1080×1350 pt — ImageRenderer scale 3x → 3240×4050 px)
    static let cardWidth: CGFloat  = 360   // 1080 / 3
    static let cardHeight: CGFloat = 450   // 1350 / 3

    private var usesImageBackground: Bool {
        switch background {
        case .gradient: return false
        case .coverImage, .photo: return true
        }
    }

    private var primaryTextColor: Color {
        usesImageBackground ? .white : Color.primary
    }

    private var secondaryTextColor: Color {
        usesImageBackground ? .white.opacity(0.75) : Color.secondary
    }

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipped()
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .gradient:
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.85),
                    Color.accentColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .coverImage(let img):
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.45))
        case .photo(let img):
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.40))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            switch mode {
            case .session(let elapsed, let pages, let pace, let title, let author, let showTitle):
                sessionContent(
                    elapsed: elapsed,
                    pages: pages,
                    pace: pace,
                    title: title,
                    author: author,
                    showTitle: showTitle
                )
            case .snippet(let text, let tag, let title, let author):
                snippetContent(text: text, tag: tag, title: title, author: author)
            }

            Spacer()

            // 워드마크 (하단)
            wordmark
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Session Content

    private func sessionContent(
        elapsed: String,
        pages: Int,
        pace: Double,
        title: String,
        author: String,
        showTitle: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 레이블
            Text("오늘의 독서 완료")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(primaryTextColor.opacity(0.7))

            // 통계 3열
            HStack(spacing: 0) {
                statItem(label: "독서 시간", value: elapsed)
                Spacer()
                statItem(label: "읽은 페이지", value: "\(pages)p")
                Spacer()
                statItem(label: "페이스", value: String(format: "%.1f min/p", pace))
            }

            // 책 정보 (토글 옵션)
            if showTitle && !title.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                    if !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)
        }
    }

    // MARK: - Snippet Content

    private func snippetContent(
        text: String,
        tag: String?,
        title: String,
        author: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 태그 pill
            if let tag, !tag.isEmpty {
                Text(tag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(primaryTextColor.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(primaryTextColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            // 인용 텍스트
            Text("\"\(text)\"")
                .font(.system(size: 18, design: .serif))
                .foregroundStyle(primaryTextColor)
                .lineSpacing(7)
                .lineLimit(8)

            // 책 정보
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                    if !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        HStack(spacing: 6) {
            Image(systemName: "book.pages")
                .font(.caption.weight(.medium))
                .foregroundStyle(primaryTextColor.opacity(0.6))
            Text("Snippet")
                .font(.system(size: 13, weight: .light))
                .kerning(2.5)
                .foregroundStyle(primaryTextColor.opacity(0.6))
        }
    }
}
