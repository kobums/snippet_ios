import SwiftUI

/// 기록 카드 (GlassContainer 대응 — 일반 카드).
/// 상단 행: #태그 pill(좌) / p.페이지 + 날짜(우, tertiary) → 본문 텍스트(최대 5줄).
struct RecordCardView: View {

    let record: RecordDto

    private var formattedDate: String {
        let raw = record.createDate
        // "yyyy-MM-dd'T'HH:mm:ss" 또는 "yyyy-MM-dd" 처리
        let prefix = String(raw.prefix(10))
        let parts = prefix.split(separator: "-")
        guard parts.count == 3 else { return prefix }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 상단 메타 행
            HStack {
                // 태그 pill
                if let tag = record.tag, !tag.isEmpty {
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                        )
                }

                Spacer()

                // 페이지 + 날짜
                HStack(spacing: 6) {
                    if let page = record.relatedPage {
                        Text("p.\(page)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // 본문 — 스니펫(인용문)은 앱 시그니처인 세리프 타이포그래피
            Text(record.text)
                .font(record.type == .snippet ? .quoteBody : .body)
                .lineLimit(5)
                .lineSpacing(record.type == .snippet ? 6 : 2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - 책별 그룹 헤더

/// 기록·세션 목록의 책별 그룹 헤더 — 표지 썸네일 + 세리프 제목 + 저자 + 건수.
/// 제목만 있던 텍스트 헤더 대신 어떤 책인지 한눈에 보이게 한다.
struct RecordBookGroupHeader: View {

    let title: String
    var author: String? = nil
    var coverUrl: String? = nil
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            BookCoverView(
                urlString: coverUrl,
                size: .custom(width: 34, height: 48, cornerRadius: 4),
                showsShadow: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.serifHeadline)
                    .lineLimit(1)
                if let author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(count)")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        RecordBookGroupHeader(title: "데미안", author: "헤르만 헤세", count: 3)
        RecordCardView(record: RecordDto.preview)
    }
    .padding()
}

private extension RecordDto {
    static let preview = RecordDto(
        id: 1, bookId: 1,
        bookTitle: "데미안", bookAuthor: "헤르만 헤세", bookCoverUrl: "",
        type: .snippet,
        text: "새는 알에서 나오려고 투쟁한다. 알은 세계다. 태어나려는 자는 하나의 세계를 깨뜨려야 한다.",
        tag: "인상깊은", relatedPage: 42,
        createDate: "2026-06-10T10:30:00"
    )
}
