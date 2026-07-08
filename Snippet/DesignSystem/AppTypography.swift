import SwiftUI

// MARK: - 타이포그래피
//
// 원칙(docs/native-migration/03-design-system.md §7.2):
// 본문/제목은 전부 시스템 Dynamic Type을 사용한다.
//   h1~h4   → .largeTitle / .title / .title2 / .title3(또는 .headline)
//   body    → .body / .subheadline / .caption
//   label   → .headline / .subheadline.weight(.medium)
// 커스텀은 시그니처 스타일(quote, 브랜드 워드마크, 통계 숫자)만 유지한다.

extension Font {

    /// 스와이프 카드 인용문 — 앱의 시그니처 (20pt, New York 세리프). `quoteStyle()`과 함께 사용 권장.
    static let quote = Font.system(size: 20, weight: .regular, design: .serif)

    /// 목록용 인용문 (17pt, 세리프) — 보관함 카드 등.
    static let quoteBody = Font.system(size: 17, design: .serif)

    /// 책 제목 대 (title3 상당, 세리프 semibold) — Reveal 등 책 공개 연출.
    static let serifTitle = Font.system(size: 20, weight: .semibold, design: .serif)

    /// 책 제목 소 (headline 상당, 세리프 semibold) — 책 헤더, 목록 제목.
    static let serifHeadline = Font.system(size: 17, weight: .semibold, design: .serif)

    /// 브랜드 로고 워드마크 (28pt, light 세리프, 자간 5). `brandWordmarkStyle()`과 함께 사용 권장.
    static let brandWordmark = Font.system(size: 28, weight: .light, design: .serif)

    /// 통계 숫자 대 (40pt, semibold) — 대시보드 초대형 숫자.
    static let statValueLarge = Font.system(size: 40, weight: .semibold)

    /// 통계 숫자 중 (32pt, semibold) — StatCardView 값.
    static let statValue = Font.system(size: 32, weight: .semibold)

    /// 통계 숫자 소 (24pt, semibold).
    static let statValueSmall = Font.system(size: 24, weight: .semibold)
}

extension View {

    /// 스와이프 카드 인용문 스타일: 20pt 세리프 + 줄간격 8 (lineHeight 1.6 상당).
    func quoteStyle() -> some View {
        self
            .font(.quote)
            .lineSpacing(8)
    }

    /// 브랜드 워드마크 스타일: 28pt light + 자간 5.
    func brandWordmarkStyle() -> some View {
        self
            .font(.brandWordmark)
            .kerning(5)
    }
}
