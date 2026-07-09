import SwiftUI

// MARK: - PopularBooksView

/// 인기 도서 목록 (국립중앙도서관 인기 대출 기반).
/// 필터: 기간 / 장르(KDC) / 연령 / 성별
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
            VStack(spacing: 0) {
                // 필터 바
                filterBars

                // 콘텐츠
                if viewModel.isLoadingPopular && viewModel.popularBooks.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
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

    private var filterBars: some View {
        VStack(spacing: 0) {
            // 기간 필터
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PeriodFilter.allCases, id: \.self) { filter in
                        FilterChip(label: filter.rawValue, isSelected: selectedPeriod == filter) {
                            selectedPeriod = filter
                            applyFilters()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // 장르 필터
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(KdcFilter.allCases, id: \.self) { filter in
                        FilterChip(label: filter.rawValue, isSelected: selectedKdc == filter) {
                            selectedKdc = filter
                            applyFilters()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // 연령 필터
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AgeFilter.allCases, id: \.self) { filter in
                        FilterChip(label: filter.rawValue, isSelected: selectedAge == filter) {
                            selectedAge = filter
                            applyFilters()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // 성별 필터
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GenderFilter.allCases, id: \.self) { filter in
                        FilterChip(label: filter.rawValue, isSelected: selectedGender == filter) {
                            selectedGender = filter
                            applyFilters()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Divider()
        }
    }

    private var bookList: some View {
        List {
            ForEach(viewModel.popularBooks, id: \.isbn13) { book in
                PopularBookRow(book: book) {
                    selectedBook = book
                }
                .onAppear {
                    if book == viewModel.popularBooks.last {
                        Task { await viewModel.loadMorePopular() }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.onAccent : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PopularBookRow

private struct PopularBookRow: View {
    let book: PopularBookDto
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 순위 뱃지
            ZStack {
                Circle()
                    .fill(book.rank <= 3 ? Color.accentColor : Color(.secondarySystemBackground))
                    .frame(width: 28, height: 28)
                Text("\(book.rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(book.rank <= 3 ? Color.onAccent : .secondary)
            }

            BookCoverView(urlString: book.coverUrl, size: .large)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(book.publisher)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                if book.loanCount > 0 {
                    Text("대출 \(book.loanCount)회")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentText)
                }
            }

            Spacer()

            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Color.accentText)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
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
                        Picker("분류", selection: $selectedType) {
                            Text("위시리스트").tag(BookType.wish)
                            Text("소장").tag(BookType.have)
                            Text("대출").tag(BookType.borrow)
                        }
                        .pickerStyle(.segmented)
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
                            Picker("상태", selection: $selectedStatus) {
                                Text("읽을 예정").tag(BookStatus.waiting)
                                Text("읽는 중").tag(BookStatus.reading)
                                Text("완독").tag(BookStatus.completed)
                            }
                            .pickerStyle(.segmented)
                        }
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
                        Task {
                            _ = await viewModel.addBook(request)
                        }
                        onComplete()
                        dismiss()
                    } label: {
                        Text("추가하기")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.onAccent)
                }
                .padding()
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
