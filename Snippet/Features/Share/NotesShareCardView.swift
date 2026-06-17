import SwiftUI

// MARK: - NotesShareCardView

/// 독서 기록 메모를 4:5(1080×1350) "줄지어진 노트" 카드로 렌더링하는 뷰.
///
/// Flutter `NotesExportSection`의 `_NotesPageCard`를 SwiftUI로 포팅.
/// 본문이 길면 여러 페이지로 분할되어 한 장당 하나의 카드를 렌더링한다.
/// - 첫 페이지: 타입 배지 + 작성일 + 책 제목(굵게) + 저자.
/// - 이어지는 페이지: 미니 헤더(책 제목 + "i / N").
/// - 본문: 줄지어진 노트 배경 위 텍스트.
/// - 푸터: 우측 정렬 "snippet" 워드마크.
///
/// `ShareCardView` 규약(cardWidth 360 / cardHeight 450, ImageRenderer scale 3 → 1080×1350)을 따른다.
struct NotesShareCardView: View {

    let typeLabel: String
    let createDate: String
    let bookTitle: String
    let bookAuthor: String
    let bodyText: String
    let isFirstPage: Bool
    let pageIndex: Int
    let totalPages: Int

    /// 다크/라이트 강제 지정(렌더링 시 환경 colorScheme과 무관하게 고정하기 위함).
    let isDark: Bool

    // 렌더링용 고정 크기 — ShareCardView와 동일 규약 (1080×1350 px @ scale 3)
    static let cardWidth: CGFloat  = 360   // 1080 / 3
    static let cardHeight: CGFloat = 450   // 1350 / 3

    // ── 레이아웃 상수 (Flutter 1080px 기준 → 360px 카드로 1/3 스케일) ──
    // Flutter 카드는 폭 1080 기준이지만 여기선 360폭으로 렌더 후 scale 3.
    // 패딩/폰트는 360폭 기준 px 값으로 정의.
    static let bodyHPad: CGFloat = 20
    static let bodyVPad: CGFloat = 14
    static let lineHeight: CGFloat = 26
    static let bodyFontSize: CGFloat = 15

    // 노란 배지 색 (Flutter와 동일)
    private static let yellow = Color(red: 1.0, green: 0.8, blue: 0.0)              // #FFCC00
    private static let yellowLabel = Color(red: 0.545, green: 0.412, blue: 0.078)  // #8B6914

    // ── 시맨틱 색상 (다크/라이트) ──
    private var bg: Color { isDark ? Color(red: 0.110, green: 0.110, blue: 0.118) : .white }                       // #1C1C1E / white
    private var textPrimary: Color { isDark ? .white : Color(red: 0.110, green: 0.110, blue: 0.118) }              // white / #1C1C1E
    private var textSecondary: Color { isDark ? Color(red: 0.557, green: 0.557, blue: 0.576) : Color(red: 0.424, green: 0.424, blue: 0.439) } // #8E8E93 / #6C6C70
    private var dividerColor: Color { isDark ? Color(red: 0.220, green: 0.220, blue: 0.227) : Color(red: 0.898, green: 0.898, blue: 0.918) } // #38383A / #E5E5EA
    private var lineColor: Color { isDark ? Color(red: 0.145, green: 0.145, blue: 0.153) : Color(red: 0.941, green: 0.941, blue: 0.961) }    // #252527 / #F0F0F5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // 상단 구분선
            Divider()
                .frame(height: 1)
                .overlay(dividerColor)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // 본문 (남은 공간 채움)
            ruledBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 하단 구분선
            Divider()
                .frame(height: 1)
                .overlay(dividerColor)
                .padding(.horizontal, 20)

            // 푸터
            footer
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(bg)
        .clipped()
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if isFirstPage {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(typeLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Self.yellowLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Self.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Text(formattedDate(createDate))
                        .font(.system(size: 11))
                        .tracking(-0.1)
                        .foregroundStyle(textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(bookTitle)
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .lineSpacing(22 * 0.2)
                        .foregroundStyle(textPrimary)
                    if !bookAuthor.isEmpty {
                        Text(bookAuthor)
                            .font(.system(size: 13))
                            .tracking(-0.1)
                            .foregroundStyle(textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        } else {
            HStack {
                Text(bookTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(pageIndex + 1) / \(totalPages)")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    // MARK: - Ruled Body

    private var ruledBody: some View {
        ZStack(alignment: .topLeading) {
            // 줄지어진 노트 배경
            LinedPaperShape(
                hPad: Self.bodyHPad,
                vPad: Self.bodyVPad,
                lineHeight: Self.lineHeight,
                fontSize: Self.bodyFontSize
            )
            .stroke(lineColor, lineWidth: 1)

            // 본문 텍스트
            Text(bodyText)
                .font(.system(size: Self.bodyFontSize))
                .tracking(-0.1)
                .lineSpacing(Self.lineHeight - Self.bodyFontSize)
                .foregroundStyle(textPrimary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, Self.bodyHPad)
                .padding(.vertical, Self.bodyVPad)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 4) {
            Spacer()
            Image(systemName: "book.pages")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary)
            Text("snippet")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func formattedDate(_ iso: String) -> String {
        guard let date = APIDate.parseDateTime(iso) ?? APIDate.parseDay(iso) else {
            return iso
        }
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        if let y = comps.year, let m = comps.month, let d = comps.day {
            return "\(y)년 \(m)월 \(d)일"
        }
        return iso
    }
}

// MARK: - LinedPaperShape

/// 본문 영역에 수평 줄(노트 괘선)을 그리는 Shape.
///
/// Flutter `_LinedPaperPainter`와 동일하게 텍스트 descender 직후 위치에 줄을 그린다.
struct LinedPaperShape: Shape {

    let hPad: CGFloat
    let vPad: CGFloat
    let lineHeight: CGFloat
    let fontSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 텍스트 baseline 아래로 약간 내린 위치 (Flutter: (lineH - fontSize) * 0.45)
        let lineOffset = (lineHeight - fontSize) * 0.45
        var y = vPad + lineHeight - lineOffset
        while y < rect.height - vPad / 2 {
            path.move(to: CGPoint(x: hPad, y: y))
            path.addLine(to: CGPoint(x: rect.width - hPad, y: y))
            y += lineHeight
        }
        return path
    }
}
