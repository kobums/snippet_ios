import SwiftUI

/// 섹션 헤더: 타이틀 + 선택적 trailing 액션 버튼 ("전체 보기" 등).
struct SectionHeaderView: View {

    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SectionHeaderView(title: "이번 달 통계")
        SectionHeaderView(title: "내 서재", actionTitle: "전체 보기", action: {})
    }
    .padding()
}
