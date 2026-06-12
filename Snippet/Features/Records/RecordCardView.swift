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

            // 본문
            Text(record.text)
                .font(.body)
                .lineLimit(5)
                .lineSpacing(2)
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

#Preview {
    RecordCardView(record: RecordDto.preview)
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

    init(id: Int, bookId: Int, bookTitle: String, bookAuthor: String, bookCoverUrl: String,
         type: RecordType, text: String, tag: String?, relatedPage: Int?, createDate: String) {
        self.id = id
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.bookCoverUrl = bookCoverUrl
        self.type = type
        self.text = text
        self.tag = tag
        self.relatedPage = relatedPage
        self.createDate = createDate
    }
}
