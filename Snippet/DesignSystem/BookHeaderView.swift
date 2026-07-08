import SwiftUI

/// 책 헤더: 표지(72×100) + 제목 + 저자 + 선택적 배지 가로 레이아웃.
/// Flutter `AppBookHeader` 대응 — 독서 기록/세션 상세 헤더에서 공유.
struct BookHeaderView: View {

    let title: String
    var author: String?
    var coverURLString: String?
    var badge: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverView(urlString: coverURLString, size: .header)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.serifHeadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Color.primary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    BookHeaderView(
        title: "데미안: 에밀 싱클레어의 젊은 날의 이야기",
        author: "헤르만 헤세",
        coverURLString: nil,
        badge: "읽는 중"
    )
    .padding()
}
