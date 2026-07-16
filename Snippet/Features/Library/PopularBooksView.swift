import SwiftUI

// MARK: - PopularBooksView

/// 인기 도서 목록 (국립중앙도서관 인기 대출 기반).
/// 필터: 기간 / 장르(KDC) / 연령 / 성별 — 글래스 칩 Menu 한 줄로 압축.
struct PopularBooksView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LibraryViewModel
    @State private var selectedBook: PopularBookDto? = nil

    // 필터 선택 상태
    @State private var selectedPeriod: PeriodFilter = .week
    @State private var selectedKdc: KdcFilter = .all
    @State private var selectedAge: AgeFilter = .all
    @State private var selectedGender: GenderFilter = .all

    enum PeriodFilter: String, CaseIterable {
        case week = "1주일"
        case month = "1개월"
        case threeMonths = "3개월"
        case halfYear = "6개월"
        case year = "1년"

        var dateRange: (start: String, end: String) {
            let end = APIDate.dayString()
            let calendar = Calendar.current
            let days: Int
            switch self {
            case .week: days = 7
            case .month: days = 30
            case .threeMonths: days = 90
            case .halfYear: days = 180
            case .year: days = 365
            }
            let start = APIDate.dayString(from: calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date())
            return (start, end)
        }
    }

    enum KdcFilter: String, CaseIterable {
        case all = "전체"
        case literature = "문학"
        case socialScience = "사회과학"
        case history = "역사"
        case naturalScience = "자연과학"
        case technology = "기술과학"
        case art = "예술"
        case language = "언어"
        case philosophy = "철학"
        case religion = "종교"

        var kdc: String? {
            switch self {
            case .all: return nil
            case .literature: return "8"
            case .socialScience: return "3"
            case .history: return "9"
            case .naturalScience: return "4"
            case .technology: return "5"
            case .art: return "6"
            case .language: return "7"
            case .philosophy: return "1"
            case .religion: return "2"
            }
        }
    }

    enum AgeFilter: String, CaseIterable {
        case all = "전체"
        case child = "아동"
        case youth = "청소년"
        case adult = "성인"

        var age: String? {
            switch self {
            case .all: return nil
            case .child: return "child"
            case .youth: return "young"
            case .adult: return "adult"
            }
        }
    }

    enum GenderFilter: String, CaseIterable {
        case all = "전체"
        case male = "남성"
        case female = "여성"

        var gender: String? {
            switch self {
            case .all: return nil
            case .male: return "male"
            case .female: return "female"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingPopular && viewModel.popularBooks.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.popularError, viewModel.popularBooks.isEmpty {
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: "인기 도서 정보를 불러올 수 없습니다",
                        message: error,
                        actionTitle: "다시 시도",
                        action: { Task { await viewModel.loadPopular(refresh: true) } }
                    )
                } else if viewModel.popularBooks.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "인기 도서 정보를 불러올 수 없습니다",
                        message: nil
                    )
                } else {
                    bookList
                }
            }
            // 필터 칩은 플로팅 글래스 크롬 — 리스트가 아래로 스크롤되며 비쳐 보인다.
            .safeAreaInset(edge: .top, spacing: 0) { filterBar }
            .navigationTitle("인기 도서")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(item: $selectedBook) { book in
                AddPopularBookSheet(book: book, viewModel: viewModel) {
                    selectedBook = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .task {
                await viewModel.loadPopular(refresh: true)
            }
        }
    }

    // MARK: - 필터 바

    /// 기간/장르/연령/성별 4차원을 글래스 칩 Menu 한 줄로 — 흔한 경로(기간)는 그대로 노출하고
    /// 세부 옵션은 한 단계 아래(Menu)로 접는다. 선택된 필터는 칩 라벨 자체가 값을 말한다.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterMenu(
                    selection: $selectedPeriod,
                    label: selectedPeriod.rawValue,
                    isActive: selectedPeriod != .week
                )
                filterMenu(
                    selection: $selectedKdc,
                    label: selectedKdc == .all ? "장르" : selectedKdc.rawValue,
                    isActive: selectedKdc != .all
                )
                filterMenu(
                    selection: $selectedAge,
                    label: selectedAge == .all ? "연령" : selectedAge.rawValue,
                    isActive: selectedAge != .all
                )
                filterMenu(
                    selection: $selectedGender,
                    label: selectedGender == .all ? "성별" : selectedGender.rawValue,
                    isActive: selectedGender != .all
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// 글래스 캡슐 칩 Menu — BookDetailView의 분류/상태 칩과 같은 문법.
    private func filterMenu<F: RawRepresentable & CaseIterable & Hashable>(
        selection: Binding<F>,
        label: String,
        isActive: Bool
    ) -> some View where F.RawValue == String, F.AllCases: RandomAccessCollection {
        Menu {
            Picker("", selection: Binding(
                get: { selection.wrappedValue },
                set: { newValue in
                    Haptics.selection()
                    selection.wrappedValue = newValue
                    applyFilters()
                }
            )) {
                ForEach(F.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? Color.accentText : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }

    // MARK: - 리스트

    private var bookList: some View {
        List {
            ForEach(viewModel.popularBooks, id: \.isbn13) { book in
                Button {
                    selectedBook = book
                } label: {
                    PopularBookRow(book: book)
                }
                .buttonStyle(.pressable)
                .onAppear {
                    if book == viewModel.popularBooks.last {
                        Task { await viewModel.loadMorePopular() }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            if viewModel.isLoadingPopular {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        // 필터 변경으로 목록이 갈릴 때 행이 뚝 끊기지 않도록 스프링 전환.
        .animation(.spring(response: 0.4, dampingFraction: 1.0), value: viewModel.popularBooks)
        .refreshable {
            Haptics.medium()
            await viewModel.loadPopular(refresh: true)
        }
    }

    private func applyFilters() {
        let range = selectedPeriod.dateRange
        viewModel.popularQuery.startDt = range.start
        viewModel.popularQuery.endDt = range.end
        viewModel.popularQuery.kdc = selectedKdc.kdc
        viewModel.popularQuery.age = selectedAge.age
        viewModel.popularQuery.gender = selectedGender.gender
        Task { await viewModel.loadPopular(refresh: true) }
    }
}

// MARK: - PopularBookRow

/// 행 전체가 탭 타겟 — 트레일링 + 아이콘은 어포던스일 뿐 별도 버튼이 아니다.
private struct PopularBookRow: View {
    let book: PopularBookDto

    var body: some View {
        HStack(spacing: 12) {
            // App Store 차트식 타이포그래피 순위 — 상위 3위만 액센트로 강조.
            Text("\(book.rank)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(book.rank <= 3 ? Color.accentText : Color(.tertiaryLabel))
                .frame(width: 32)

            BookCoverView(urlString: book.coverUrl, size: .large)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(book.publisher)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                if book.loanCount > 0 {
                    Text("대출 \(book.loanCount.formatted())회")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentText)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(Color.accentText)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - AddPopularBookSheet

/// 인기 도서에서 서재 추가 바텀시트.
private struct AddPopularBookSheet: View {
    let book: PopularBookDto
    let viewModel: LibraryViewModel
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: BookType = .have
    @State private var selectedStatus: BookStatus = .waiting

    private var dateStr: String {
        APIDate.dayString()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 책 정보
                    HStack(spacing: 12) {
                        BookCoverView(urlString: book.coverUrl, size: .large)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(3)
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(book.publisher)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    // 분류
                    VStack(alignment: .leading, spacing: 8) {
                        Text("분류")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        GlassSegmentedControl(
                            segments: [
                                (BookType.wish, "위시리스트"),
                                (BookType.have, "소장"),
                                (BookType.borrow, "대출"),
                            ],
                            selection: $selectedType
                        )
                        .onChange(of: selectedType) { _, newType in
                            if newType == .wish { selectedStatus = .none }
                            else if selectedStatus == .none { selectedStatus = .waiting }
                        }
                    }

                    // 상태 (위시 아님)
                    if selectedType != .wish {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("상태")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            GlassSegmentedControl(
                                segments: [
                                    (BookStatus.waiting, "읽을 예정"),
                                    (BookStatus.reading, "읽는 중"),
                                    (BookStatus.completed, "완독"),
                                ],
                                selection: $selectedStatus
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        let request = LibraryAddRequest(
                            title: book.title,
                            author: book.author,
                            publisher: book.publisher,
                            pubDate: "",
                            isbn: book.isbn13,
                            coverUrl: book.coverUrl,
                            totalPage: 0,
                            type: selectedType,
                            status: selectedType == .wish ? .none : selectedStatus,
                            readPage: 0,
                            startDate: selectedStatus == .reading || selectedStatus == .completed ? dateStr : "",
                            endDate: selectedStatus == .completed ? dateStr : "",
                            createDate: dateStr
                        )
                        Haptics.success()
                        Task {
                            _ = await viewModel.addBook(request)
                        }
                        onComplete()
                        dismiss()
                    } label: {
                        Text("추가하기")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                }
                .padding()
                // 상태 섹션이 나타나고 사라질 때 아래 버튼이 뚝 점프하지 않도록.
                .animation(.spring(response: 0.35, dampingFraction: 1.0), value: selectedType)
            }
            .navigationTitle("책 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PopularBookDto + Identifiable

extension PopularBookDto: Identifiable {
    public var id: String { isbn13.isEmpty ? title : isbn13 }
}

#Preview {
    PopularBooksView(viewModel: LibraryViewModel())
}
