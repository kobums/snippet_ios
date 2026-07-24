import SwiftUI

/// 기능 제안 화면 (SuggestionScreen).
/// 01-screens.md §7.1 스펙 기반. POST /suggestions + GET /suggestions/mine.
struct SuggestionView: View {
    private let service = SuggestionService()

    @State private var selectedCategory: SuggestionCategory = .feature
    @State private var title     = ""
    @State private var content   = ""
    @State private var isLoading = false
    @State private var serverError: String? = nil
    @State private var showSuccess = false
    @State private var contentError: String? = nil

    // 내 건의 내역
    @State private var suggestions: [SuggestionDto] = []

    var body: some View {
        NavigationStack {
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

                    // 내 건의 내역 — 비어 있으면 섹션 자체를 숨긴다
                    if !suggestions.isEmpty {
                        mySuggestionsSection
                    }
                }
                .padding(20)
            }
            .navigationTitle("기능 제안하기")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadSuggestions() }
            .alert("제안이 접수되었어요", isPresented: $showSuccess) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("소중한 의견 감사합니다. 검토 후 답변드릴게요.")
            }
        }
    }

    // MARK: - 내 건의 내역

    private var mySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("내 건의 내역")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)

            ForEach(suggestions) { item in
                suggestionRow(item)
            }
        }
    }

    private func suggestionRow(_ item: SuggestionDto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 상단 행: 카테고리 pill(좌) / 상태 뱃지(우)
            HStack {
                Text(SuggestionCategory(rawValue: item.category)?.label ?? item.category)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: Capsule())

                Spacer()

                statusBadge(item.status)
            }

            // 제목 (없으면 내용 첫 줄)
            Text(displayTitle(item))
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            // 작성일
            Text(formattedDate(item.createDate))
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))

            // 관리자 답변 — 인용 블록
            if let answer = item.answer, !answer.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentText)
                        Text("답변")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentText)
                        if let answerDate = item.answerDate, !answerDate.isEmpty {
                            Text(formattedDate(answerDate))
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    /// 상태 뱃지 — PENDING=보조색, COMPLETED=강조색.
    private func statusBadge(_ status: String) -> some View {
        let isCompleted = status == "COMPLETED"
        return Text(isCompleted ? "답변완료" : "대기중")
            .font(.caption.weight(.medium))
            .foregroundStyle(isCompleted ? Color.accentText : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isCompleted ? Color.accentColor.opacity(0.12) : Color(.secondarySystemFill),
                in: Capsule()
            )
    }

    /// 제목이 없으면 내용 첫 줄로 대체.
    private func displayTitle(_ item: SuggestionDto) -> String {
        if let title = item.title, !title.isEmpty { return title }
        return item.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? item.content
    }

    /// "yyyy-MM-dd'T'HH:mm:ss" → "yyyy.MM.dd" (RecordCardView와 동일한 표기).
    private func formattedDate(_ iso: String) -> String {
        let prefix = String(iso.prefix(10))
        let parts = prefix.split(separator: "-")
        guard parts.count == 3 else { return prefix }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    private func loadSuggestions() async {
        do {
            suggestions = try await service.mine()
        } catch {
            // 목록 로드 실패는 조용히 무시 — 제안 작성 기능에는 영향 없음
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
            title       = ""
            content     = ""
            showSuccess = true
            await loadSuggestions()
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
