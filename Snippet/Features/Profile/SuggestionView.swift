import SwiftUI

/// 기능 제안 화면 (SuggestionScreen).
/// 01-screens.md §7.1 스펙 기반. POST /suggestions.
struct SuggestionView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = SuggestionService()

    @State private var selectedCategory: SuggestionCategory = .feature
    @State private var title     = ""
    @State private var content   = ""
    @State private var isLoading = false
    @State private var serverError: String? = nil
    @State private var showSuccess = false
    @State private var contentError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // 안내문
                    Text("Snippet을 더 좋게 만들 수 있는 아이디어를 알려주세요.\n버그 신고, 기능 추가 제안 모두 환영합니다!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // 카테고리 선택 — ChoiceChip
                    VStack(alignment: .leading, spacing: 10) {
                        Text("카테고리")
                            .font(.subheadline.weight(.semibold))

                        FlowLayout(spacing: 8) {
                            ForEach(SuggestionCategory.allCases, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat.label)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            selectedCategory == cat
                                                ? Color.accentColor
                                                : Color(.secondarySystemFill)
                                        )
                                        .foregroundStyle(
                                            selectedCategory == cat ? .white : .primary
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: selectedCategory)
                            }
                        }
                    }

                    // 제목 (선택)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("제목 (선택)")
                            .font(.subheadline.weight(.semibold))
                        TextField("제목을 입력하세요 (최대 200자)", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: title) { _, new in
                                if new.count > 200 {
                                    title = String(new.prefix(200))
                                }
                            }
                    }

                    // 내용 (필수)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("내용")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $content)
                            .frame(minHeight: 160)
                            .padding(6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(contentError != nil ? Color.red : Color(.separator), lineWidth: 1)
                            )
                        if let err = contentError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // 서버 에러
                    if let err = serverError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // 제출 버튼
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("제출하기")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading)
                }
                .padding(20)
            }
            .navigationTitle("기능 제안하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - 제출

    private func submit() async {
        contentError = nil
        serverError  = nil

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            contentError = "내용을 입력해주세요."
            return
        }

        isLoading = true
        do {
            try await service.submit(
                category: selectedCategory,
                title: title.isEmpty ? nil : title,
                content: content
            )
            isLoading = false
            dismiss()
        } catch {
            serverError = error.localizedDescription
            isLoading   = false
        }
    }
}

// MARK: - FlowLayout (ChoiceChip wrap 레이아웃)

/// 가로로 칩을 배치하고 줄이 넘치면 자동 개행하는 간단한 레이아웃.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + spacing
                x  = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x  = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    SuggestionView()
}
