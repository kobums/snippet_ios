import SwiftUI

/// 기능 제안 작성 폼 (SuggestionView에서 + 버튼으로 push 진입).
/// 01-screens.md §7.1 스펙 기반. POST /suggestions.
/// 제출 성공 → 알럿 확인 → 리스트로 복귀(dismiss) + `onSubmitted`로 목록 새로고침.
struct AddSuggestionView: View {
    private let service = SuggestionService()

    /// 제출 성공 후(복귀 직전) 호출 — 리스트 새로고침용.
    var onSubmitted: () async -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SuggestionCategory = .feature
    @State private var title     = ""
    @State private var content   = ""
    @State private var isLoading = false
    @State private var serverError: String? = nil
    @State private var showSuccess = false
    @State private var contentError: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 안내 카드
                HStack(spacing: 14) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentText)
                        .frame(width: 48, height: 48)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                    Text("Snippet을 더 좋게 만들 아이디어를 알려주세요.\n버그 신고, 기능 제안 모두 환영해요!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

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
                                        selectedCategory == cat ? Color.onAccent : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: selectedCategory)
                        }
                    }
                }

                // 제목 (선택)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("제목")
                            .font(.subheadline.weight(.semibold))
                        Text("선택")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    TextField("한 줄로 요약해주세요", text: $title)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: title) { _, new in
                            if new.count > 200 {
                                title = String(new.prefix(200))
                            }
                        }
                }

                // 내용 (필수)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("내용")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(content.count)자")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(contentError != nil ? Color.red : Color.clear, lineWidth: 1)
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
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(Color.onAccent)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.subheadline)
                            Text("제안 보내기")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor)
                    .foregroundStyle(Color.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading)
            }
            .padding(20)
        }
        .navigationTitle("제안 작성")
        .navigationBarTitleDisplayMode(.inline)
        // 제출 성공 알럿 — 확인 시 리스트로 복귀
        .alert("제안이 접수되었어요", isPresented: $showSuccess) {
            Button("확인", role: .cancel) { dismiss() }
        } message: {
            Text("소중한 의견 감사합니다. 검토 후 답변드릴게요.")
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
            await onSubmitted()
            showSuccess = true
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
    NavigationStack {
        AddSuggestionView()
    }
}
