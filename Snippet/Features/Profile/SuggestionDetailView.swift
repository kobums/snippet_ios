import SwiftUI

/// 건의 상세 화면 — 리스트(`SuggestionView`) 항목 탭으로 push 진입.
/// 목록에서 받은 `SuggestionDto`를 그대로 표시하는 단순 화면 (별도 API 호출 없음).
struct SuggestionDetailView: View {
    let suggestion: SuggestionDto

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 헤더 — 카테고리 pill + 상태 뱃지 / 제목 / 작성일
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(SuggestionCategory(rawValue: suggestion.category)?.label ?? suggestion.category)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08), in: Capsule())

                        Spacer()

                        statusBadge(suggestion.status)
                    }

                    // 제목 (전체 표시, 없으면 생략)
                    if let title = suggestion.title, !title.isEmpty {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(formattedDate(suggestion.createDate))
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }

                // 건의 내용 전문
                Text(suggestion.content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                // 관리자 답변 — 있으면 인용 블록, 없으면 대기 안내
                if let answer = suggestion.answer, !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.accentText)
                            Text("답변")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentText)
                            if let answerDate = suggestion.answerDate, !answerDate.isEmpty {
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
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .foregroundStyle(.secondary)
                        Text("아직 답변을 기다리고 있어요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .navigationTitle("건의 상세")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 상태 뱃지 — PENDING=보조색, COMPLETED=강조색 (SuggestionView와 동일).
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

    /// "yyyy-MM-dd'T'HH:mm:ss" → "yyyy.MM.dd" (SuggestionView와 동일한 표기).
    private func formattedDate(_ iso: String) -> String {
        let prefix = String(iso.prefix(10))
        let parts = prefix.split(separator: "-")
        guard parts.count == 3 else { return prefix }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }
}
