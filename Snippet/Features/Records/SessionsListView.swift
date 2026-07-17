import SwiftUI

// MARK: - SessionsListView

/// 독서 세션 탭 — 전체 세션 기록 조회, 책 제목별 그룹핑.
/// 세션 시작/타이머는 별도 단계에서 구현 예정 — 조회만 지원.
struct SessionsListView: View {

    @Bindable var vm: RecordsViewModel
    /// 플로팅 바 높이만큼 스크롤 콘텐츠를 내리는 인셋 — 리스트에 직접 적용.
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0

    @State private var selectedSession: ReadingSessionDto?
    @State private var selectedBookTitle: String = ""

    var body: some View {
        Group {
            if vm.isLoadingSessions {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.sessionsError {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "불러올 수 없습니다",
                    message: error,
                    actionTitle: "다시 시도"
                ) {
                    Task { await vm.loadSessions() }
                }
            } else if vm.allSessions.isEmpty {
                EmptyStateView(
                    systemImage: "timer",
                    title: "아직 독서 세션이 없습니다",
                    message: "독서를 시작하면 세션이 여기에 기록됩니다."
                )
            } else {
                List {
                    // 총 건수 헤더
                    Section {
                        SectionHeaderView(title: "독서 세션 (\(vm.allSessions.count))")
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    // 책별 그룹 — 표지 + 세리프 제목 헤더 (기록 목록과 같은 문법)
                    ForEach(vm.groupedSessions, id: \.groupId) { group in
                        Section {
                            RecordBookGroupHeader(
                                title: group.bookTitle,
                                author: group.sessions.first?.bookAuthor,
                                coverUrl: group.sessions.first?.bookCoverUrl,
                                count: group.sessions.count
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)

                            // 세션 카드 목록 — 버튼으로 감싸 터치 다운 즉시 눌림 피드백
                            ForEach(group.sessions) { session in
                                Button {
                                    selectedBookTitle = group.bookTitle
                                    selectedSession = session
                                } label: {
                                    ReadingSessionCardView(session: session)
                                }
                                .buttonStyle(.pressable)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.top, topInset, for: .scrollContent)
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .refreshable {
                    await vm.loadSessions()
                }
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session, bookTitle: selectedBookTitle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - ReadingSessionCardView

/// 독서 세션 카드.
/// 날짜(우측 소요시간) / 시작p→종료p페이지 + +Np(녹색) / 페이스: N.N min/p
struct ReadingSessionCardView: View {

    let session: ReadingSessionDto

    private var formattedDate: String {
        let raw = session.sessionDate  // "yyyy-MM-dd"
        let parts = raw.split(separator: "-")
        guard parts.count == 3 else { return raw }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    private var formattedDuration: String {
        let total = session.durationSeconds
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        } else {
            return "\(minutes)분"
        }
    }

    private var minutesPerPage: Double {
        guard session.pagesRead > 0 else { return 0 }
        return Double(session.durationSeconds) / 60.0 / Double(session.pagesRead)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 핵심 값(소요 시간)을 가장 크게 — 페이지 이동은 보조 정보
            HStack(alignment: .firstTextBaseline) {
                Text(formattedDuration)
                    .font(.headline)
                    .monospacedDigit()

                Spacer()

                HStack(spacing: 6) {
                    Text("\(session.startPage) → \(session.endPage)p")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("+\(session.pagesRead)p")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.systemGreen))
                }
            }

            // 날짜 · 페이스
            HStack(spacing: 4) {
                Text(formattedDate)
                if minutesPerPage > 0 {
                    Text("·")
                    Text(String(format: "%.1f분/쪽", minutesPerPage))
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
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

// MARK: - SessionDetailSheet

/// 세션 카드 탭 시 표시되는 상세 시트 — 같은 데이터를 통계 그리드로 강조.
struct SessionDetailSheet: View {

    let session: ReadingSessionDto
    let bookTitle: String

    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        let parts = session.sessionDate.split(separator: "-")
        guard parts.count == 3 else { return session.sessionDate }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    private var formattedDuration: String {
        let total = session.durationSeconds
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
    }

    private var paceText: String {
        guard session.pagesRead > 0 else { return "-" }
        let mpp = Double(session.durationSeconds) / 60.0 / Double(session.pagesRead)
        return String(format: "%.1f분/쪽", mpp)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 소요 시간 강조
                VStack(spacing: 4) {
                    Text(formattedDuration)
                        .font(.system(size: 40, weight: .light))
                        .monospacedDigit()
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                // 통계 그리드
                HStack(spacing: 12) {
                    statTile(value: "\(session.pagesRead)p", label: "읽은 페이지")
                    statTile(value: "\(session.startPage)–\(session.endPage)", label: "페이지 구간")
                    statTile(value: paceText, label: "페이스")
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(bookTitle.isEmpty ? "독서 세션" : bookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
    }
}
