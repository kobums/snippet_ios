import SwiftUI
import UIKit

// MARK: - NotesPageSplitter

/// 기록 본문을 4:5 카드 한 장에 들어가는 페이지 단위로 분할하는 유틸.
///
/// Flutter `NotesExportSection._splitIntoPages` 포팅.
/// `NSAttributedString.boundingRect`로 줄 수를 측정하며, 텍스트가 잘리지 않도록
/// 보수적으로(글자 수를 적게) 자른다. 줄바꿈/공백 경계를 우선으로 페이지를 나눈다.
enum NotesPageSplitter {

    // NotesShareCardView 레이아웃 상수와 동기화 (360폭 카드 기준)
    private static let cardWidth = NotesShareCardView.cardWidth     // 360
    private static let cardHeight = NotesShareCardView.cardHeight   // 450 (= 360 * 5/4)
    private static let bodyHPad = NotesShareCardView.bodyHPad       // 20
    private static let bodyVPad = NotesShareCardView.bodyVPad       // 14
    private static let lineHeight = NotesShareCardView.lineHeight   // 26
    private static let bodyFontSize = NotesShareCardView.bodyFontSize // 15

    // 헤더/푸터 높이 추정 (NotesShareCardView 레이아웃 기준, px)
    // 첫 페이지: 상단패딩14 + 책제목(~26) + 저자(~16) + 제목패딩12 + 구분선패딩12 + 구분선1 ≈ 81
    private static let firstHeaderH: CGFloat = 14 + 26 + 16 + 12 + 12 + 1
    // 이어지는 페이지: 상단패딩20 + 미니헤더(~15) + 구분선패딩12 + 구분선1 ≈ 48
    private static let contHeaderH: CGFloat = 20 + 15 + 12 + 1
    // 푸터: 구분선1 + 상단패딩10 + 아이콘행(~14) + 하단패딩16 ≈ 41
    private static let footerH: CGFloat = 1 + 10 + 14 + 16

    private static func bodyWidth() -> CGFloat {
        cardWidth - bodyHPad * 2
    }

    private static func maxLines(isFirst: Bool) -> Int {
        let bodyH = cardHeight
            - (isFirst ? firstHeaderH : contHeaderH)
            - footerH
            - bodyVPad * 2
        return max(1, Int((bodyH / lineHeight).rounded(.down)))
    }

    /// 본문 폰트/줄간격에 맞춘 attributed string 생성.
    private static func attributed(_ text: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        // lineSpacing은 줄 사이 간격이므로 (lineHeight - fontSize)
        style.lineSpacing = lineHeight - bodyFontSize
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .paragraphStyle: style,
            .kern: -0.1,
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    /// 주어진 길이의 텍스트가 maxLines 안에 들어가는지 검사.
    private static func fits(_ text: String, length: Int, bodyW: CGFloat, maxLines: Int) -> Bool {
        let prefix = String(text.prefix(length))
        let attr = attributed(prefix)
        let bounds = attr.boundingRect(
            with: CGSize(width: bodyW, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // 허용 높이: maxLines 줄 (보수적으로 lineHeight 사용)
        let allowedHeight = CGFloat(maxLines) * lineHeight
        return bounds.height <= allowedHeight + 0.5
    }

    /// 페이지 한 장에 들어갈 최대 글자 수를 이진 탐색으로 구한다.
    private static func charsPerPage(_ text: String, bodyW: CGFloat, maxLines: Int) -> Int {
        let total = text.count
        if fits(text, length: total, bodyW: bodyW, maxLines: maxLines) { return total }

        var lo = 0, hi = total
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if fits(text, length: mid, bodyW: bodyW, maxLines: maxLines) {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }

    /// 본문을 페이지 배열로 분할한다.
    static func split(_ text: String) -> [String] {
        if text.isEmpty { return [text] }
        let bodyW = bodyWidth()
        var pages: [String] = []
        var remaining = Substring(text)
        var isFirst = true

        while !remaining.isEmpty {
            let lines = maxLines(isFirst: isFirst)
            let remainingStr = String(remaining)
            let n = charsPerPage(remainingStr, bodyW: bodyW, maxLines: lines)

            if n >= remainingStr.count || n <= 0 {
                pages.append(remainingStr)
                break
            }

            // 자를 위치를 줄바꿈/공백 경계로 조정
            var cut = n
            let chars = Array(remainingStr)
            // n 위치까지에서 마지막 \n 또는 공백 찾기
            var lastNL = -1
            var lastSP = -1
            for i in 0..<min(cut, chars.count) {
                if chars[i] == "\n" { lastNL = i }
                else if chars[i] == " " { lastSP = i }
            }
            let boundary = max(lastNL, lastSP)
            if boundary > 0 { cut = boundary }

            let pageStr = String(chars[0..<cut])
                .trimmingTrailingWhitespace()
            pages.append(pageStr)

            let rest = String(chars[cut...]).trimmingLeadingWhitespace()
            remaining = Substring(rest)
            isFirst = false

            // 안전 가드 (무한 루프 방지)
            if pages.count > 200 { break }
        }

        return pages.isEmpty ? [text] : pages
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var s = self
        while let last = s.last, last == " " || last == "\n" || last == "\t" {
            s.removeLast()
        }
        return s
    }
    func trimmingLeadingWhitespace() -> String {
        var s = Substring(self)
        while let first = s.first, first == " " || first == "\n" || first == "\t" {
            s = s.dropFirst()
        }
        return String(s)
    }
}

// MARK: - NotesExportRenderer

/// 분할된 페이지들을 각각 UIImage로 렌더링하고 임시 PNG로 저장한다.
@MainActor
enum NotesExportRenderer {

    /// 기록 본문을 페이지별 카드 PNG로 렌더링하고 파일 URL 배열을 반환한다.
    static func renderPages(
        typeLabel: String,
        createDate: String,
        bookTitle: String,
        bookAuthor: String,
        text: String,
        isDark: Bool
    ) -> [URL] {
        let pages = NotesPageSplitter.split(text)
        var urls: [URL] = []

        for (i, page) in pages.enumerated() {
            let card = NotesShareCardView(
                typeLabel: typeLabel,
                createDate: createDate,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                bodyText: page,
                isFirstPage: i == 0,
                pageIndex: i,
                totalPages: pages.count,
                isDark: isDark
            )
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            if let image = renderer.uiImage,
               let url = ShareCardRenderer.saveTempPNG(image) {
                urls.append(url)
            }
        }
        return urls
    }
}

// MARK: - NotesExportSheet

/// 메모 이미지 내보내기 시트.
///
/// 좌우 페이지 미리보기 + 페이지 도트 + "이미지로 내보내기" 버튼을 제공하며,
/// 내보내기 시 모든 페이지 PNG를 시스템 공유 시트로 공유한다.
struct NotesExportSheet: View {

    let record: RecordDto

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var pages: [String] = []
    @State private var currentPage = 0
    @State private var isSharing = false
    @State private var showShare = false
    @State private var shareURLs: [URL] = []

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if pages.count > 1 {
                    Text("총 \(pages.count)장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                // 좌우 스크롤 미리보기
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        NotesShareCardView(
                            typeLabel: record.type.label,
                            createDate: record.createDate,
                            bookTitle: record.bookTitle,
                            bookAuthor: record.bookAuthor,
                            bodyText: page,
                            isFirstPage: i == 0,
                            pageIndex: i,
                            totalPages: pages.count,
                            isDark: isDark
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: NotesShareCardView.cardHeight + 40)

                // 페이지 도트
                if pages.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.accentColor : Color(.systemGray4))
                                .frame(width: i == currentPage ? 16 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                }

                Spacer()

                // 내보내기 버튼
                if isSharing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Button {
                        export()
                    } label: {
                        Label(
                            pages.count > 1 ? "\(pages.count)장으로 내보내기" : "이미지로 내보내기",
                            systemImage: "square.and.arrow.up"
                        )
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
            .navigationTitle("메모 이미지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                if pages.isEmpty {
                    pages = NotesPageSplitter.split(record.text)
                }
            }
            .sheet(isPresented: $showShare) {
                if !shareURLs.isEmpty {
                    ActivityShareSheet(activityItems: shareURLs)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private func export() {
        isSharing = true
        Task { @MainActor in
            let urls = NotesExportRenderer.renderPages(
                typeLabel: record.type.label,
                createDate: record.createDate,
                bookTitle: record.bookTitle,
                bookAuthor: record.bookAuthor,
                text: record.text,
                isDark: isDark
            )
            shareURLs = urls
            isSharing = false
            if !urls.isEmpty {
                showShare = true
            }
        }
    }
}
