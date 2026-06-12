import SwiftUI

/// 대시보드 통계 카드: 아이콘 칩 + 값(라이트 웨이트 대형 숫자) + 라벨.
/// Flutter `StatsCard`(glass) 대응 — 글래스는 시스템 머티리얼로 대체.
struct StatCardView: View {

    let icon: String
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Text(value)
                .font(.statValue)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCardView(icon: "book", value: "12", label: "완독한 책")
        StatCardView(icon: "clock", value: "3.5h", label: "독서 시간", tint: .brandGreen)
    }
    .padding()
}
