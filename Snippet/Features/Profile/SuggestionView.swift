import SwiftUI

/// 기능 제안 화면 (SuggestionScreen) — 내 건의 내역 리스트.
/// 01-screens.md §7.1 스펙 기반. GET /suggestions/mine.
/// 작성 폼(`AddSuggestionView`)은 툴바 + 버튼으로 push 진입.
struct SuggestionView: View {
    private let service = SuggestionService()

    @State private var suggestions: [SuggestionDto] = []
    @State private var isLoading   = true
    @State private var showAddForm = false
    @State private var selectedSuggestion: SuggestionDto? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if suggestions.isEmpty {
                // 빈 상태 — 작성 유도
                EmptyStateView(
                    systemImage: "lightbulb",
                    title: "아직 건의한 내용이 없어요",
                    message: "버그 신고, 기능 제안 모두 환영해요.\n첫 번째 아이디어를 들려주세요!",
                    actionTitle: "제안 작성하기",
                    action: { showAddForm = true }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(suggestions) { item in
                            suggestionRow(item)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("기능 제안하기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("제안 작성")
            }
        }
        // 작성 폼 push — 제출 성공 시 폼이 닫히면서 목록 새로고침
        .navigationDestination(isPresented: $showAddForm) {
            AddSuggestionView {
                await loadSuggestions()
            }
        }
        // 항목 탭 → 상세 push
        .navigationDestination(item: $selectedSuggestion) { item in
            SuggestionDetailView(suggestion: item)
        }
        .task { await loadSuggestions() }
    }

    // MARK: - 내 건의 내역 행

    private func suggestionRow(_ item: SuggestionDto) -> some View {
        Button {
            selectedSuggestion = item
        } label: {
            suggestionRowContent(item)
        }
        .buttonStyle(.plain)
    }

    private func suggestionRowContent(_ item: SuggestionDto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 상단 행: 카테고리 pill(좌) / 상태 뱃지 + chevron(우)
            HStack {
                Text(SuggestionCategory(rawValue: item.category)?.label ?? item.category)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: Capsule())

                Spacer()

                statusBadge(item.status)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
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
            // 목록 로드 실패는 조용히 무시 — 빈 상태 안내로 대체
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SuggestionView()
    }
}
