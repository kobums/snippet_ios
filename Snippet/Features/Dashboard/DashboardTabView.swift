import SwiftUI
import Charts

// MARK: - DashboardTabView

/// 대시보드 탭 루트 — 통계 | 진행 | 서재 서브탭.
struct DashboardTabView: View {

    @State private var vm = DashboardViewModel()
    @State private var selectedSubTab: SubTab = .stats

    enum SubTab: Int, CaseIterable {
        case stats, progress, library

        var title: String {
            switch self {
            case .stats:    "통계"
            case .progress: "진행"
            case .library:  "서재"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("탭", selection: $selectedSubTab) {
                    ForEach(SubTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                TabView(selection: $selectedSubTab) {
                    DashboardStatsSection(vm: vm)
                        .tag(SubTab.stats)
                    DashboardProgressSection(vm: vm)
                        .tag(SubTab.progress)
                    DashboardLibrarySection(vm: vm)
                        .tag(SubTab.library)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
            }
            .navigationTitle("대시보드")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        StatsDetailView(vm: vm)
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }
            }
            .task { await vm.loadAll() }
        }
    }
}

// MARK: - 통계 섹션

private struct DashboardStatsSection: View {

    @Bindable var vm: DashboardViewModel
    @State private var showGoalDialog = false
    @State private var goalInput = ""
    @State private var navigateToCalendar = false
    @State private var navigateToStats = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 월 네비게이터
                MonthNavigatorView(year: $vm.selectedYear, month: $vm.selectedMonth)
                    .padding(.horizontal, 16)
                    .onChange(of: vm.selectedYear) { _, _ in
                        Task { await vm.changeMonth(year: vm.selectedYear, month: vm.selectedMonth) }
                    }
                    .onChange(of: vm.selectedMonth) { _, _ in
                        Task { await vm.changeMonth(year: vm.selectedYear, month: vm.selectedMonth) }
                    }

                // 독서 목표 카드
                ReadingGoalCard(vm: vm)
                    .padding(.horizontal, 16)

                // 이번 달 통계 카드
                NavigationLink {
                    StatsDetailView(vm: vm)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "이번 달 통계")
                        HStack(spacing: 12) {
                            StatCardView(
                                icon: "books.vertical.fill",
                                value: "\(vm.completedBooksThisMonth.count)권",
                                label: "완독한 책"
                            )
                            StatCardView(
                                icon: "doc.text",
                                value: "\(vm.totalPagesThisMonth)쪽",
                                label: "총 페이지",
                                tint: .brandGreen
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                // 독서 스트릭
                StreakCard(streak: vm.streak)
                    .padding(.horizontal, 16)

                // 추천 도서
                if !vm.recommendedBooks.isEmpty {
                    RecommendationSection(books: vm.recommendedBooks) {
                        Task { await vm.loadRecommendations() }
                    }
                }

                // 독서 캘린더 미리보기
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeaderView(
                        title: "독서 캘린더",
                        actionTitle: "전체 보기"
                    ) {
                        navigateToCalendar = true
                    }
                    .padding(.horizontal, 16)

                    MiniCalendarView(
                        year: vm.selectedYear,
                        month: vm.selectedMonth,
                        books: vm.monthlyBooks
                    )
                    .padding(.horizontal, 16)
                }

                // 월별 차트 (Swift Charts 막대)
                if !vm.monthlyStats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "월별 완독 현황")
                            .padding(.horizontal, 16)
                        MonthlyBarChartView(stats: vm.monthlyStats)
                            .frame(height: 200)
                            .padding(.horizontal, 16)
                    }
                }

                // 카테고리 도넛 차트
                if !vm.categoryStats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "카테고리 분포")
                            .padding(.horizontal, 16)
                        CategoryDonutChartView(stats: vm.categoryStats)
                            .frame(height: 220)
                            .padding(.horizontal, 16)
                    }
                }

                // 완독한 책 리스트
                if !vm.completedBooksThisMonth.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "완독한 책 (\(vm.completedBooksThisMonth.count))")
                            .padding(.horizontal, 16)
                        ForEach(vm.completedBooksThisMonth) { book in
                            BookRowView(book: book)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
        .refreshable { await vm.refreshStats() }
        .navigationDestination(isPresented: $navigateToCalendar) {
            ReadingCalendarView(
                initialYear: vm.selectedYear,
                initialMonth: vm.selectedMonth,
                books: vm.monthlyBooks
            )
        }
    }
}

// MARK: - 진행 섹션

private struct DashboardProgressSection: View {

    @Bindable var vm: DashboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 세그먼트 필터
            Picker("상태", selection: $vm.selectedProgressStatus) {
                Text("대기중").tag(BookStatus.waiting)
                Text("읽는중").tag(BookStatus.reading)
                Text("완독").tag(BookStatus.completed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if vm.filteredProgressBooks.isEmpty {
                EmptyStateView(
                    systemImage: "book",
                    title: "책이 없습니다",
                    message: "이 상태의 책이 없습니다."
                )
            } else {
                List(vm.filteredProgressBooks) { book in
                    BookRowView(book: book, showProgress: true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await vm.refreshProgress() }
            }
        }
    }
}

// MARK: - 서재 섹션

private struct DashboardLibrarySection: View {

    @Bindable var vm: DashboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 검색 필드
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("제목이나 저자로 검색...", text: $vm.librarySearchQuery)
                    .autocorrectionDisabled()
                if !vm.librarySearchQuery.isEmpty {
                    Button {
                        vm.librarySearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if vm.filteredLibraryBooks.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: vm.librarySearchQuery.isEmpty ? "아직 책이 없습니다" : "검색 결과가 없습니다",
                    message: vm.librarySearchQuery.isEmpty ? "첫 책을 추가해보세요!" : "다른 검색어를 시도해보세요"
                )
            } else {
                List(vm.filteredLibraryBooks) { book in
                    BookRowView(book: book, showProgress: true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await vm.refreshLibrary() }
            }
        }
    }
}

// MARK: - 독서 목표 카드

private struct ReadingGoalCard: View {

    @Bindable var vm: DashboardViewModel
    @State private var showGoalDialog = false
    @State private var goalInput = ""

    private var goal: ReadingGoalDto { vm.readingGoal }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("올해 독서 목표")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(goal.targetBooks == 0 ? "목표 설정" : "수정") {
                    goalInput = goal.targetBooks > 0 ? String(goal.targetBooks) : ""
                    showGoalDialog = true
                }
                .font(.subheadline)
            }

            if goal.targetBooks == 0 {
                Text("올해 읽고 싶은 책 권수를 설정해보세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(goal.completedBooks)")
                        .font(.statValue)
                    Text("/ \(goal.targetBooks)권")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(goal.progress * 100))%")
                        .font(.headline)
                        .foregroundStyle(goal.progress >= 1 ? Color.brandGreen : Color.primary)
                }

                ProgressView(value: goal.progress)
                    .tint(goal.progress >= 1 ? Color.brandGreen : Color.primary)

                if goal.progress >= 1 {
                    Text("🎉 목표 달성! 축하합니다!")
                        .font(.caption)
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .alert("독서 목표 설정", isPresented: $showGoalDialog) {
            TextField("목표 권수", text: $goalInput)
                .keyboardType(.numberPad)
            Button("저장") {
                if let n = Int(goalInput), n > 0 {
                    Task { await vm.updateGoal(targetBooks: n) }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("올해 완독하고 싶은 책의 권수를 입력하세요.")
        }
    }
}

// MARK: - 스트릭 카드

private struct StreakCard: View {

    let streak: StreakDto

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("독서 스트릭")
                        .font(.subheadline.weight(.semibold))
                }
                if let last = streak.lastReadDate {
                    Text("마지막 독서: \(last)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(streak.currentStreak)")
                        .font(.statValue)
                        .foregroundStyle(streak.currentStreak > 0 ? Color(.systemOrange) : .primary)
                    Text("일")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("최장 \(streak.maxStreak)일")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 추천 도서 섹션

private struct RecommendationSection: View {

    let books: [BookRecommendDto]
    let onRefresh: () -> Void

    /// .sheet(item:)용 Identifiable 래퍼 (String은 Identifiable이 아님).
    private struct SearchTitle: Identifiable {
        let id = UUID()
        let title: String
    }

    @State private var libraryVM = LibraryViewModel()
    @State private var searchTitle: SearchTitle? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "✨ 추천 도서", actionTitle: "새로고침") {
                onRefresh()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(books) { book in
                        Button {
                            searchTitle = SearchTitle(title: book.title)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                AsyncImage(url: URL(string: book.coverUrl)) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Color(.secondarySystemBackground)
                                            .overlay(Image(systemName: "book.closed").foregroundStyle(.tertiary))
                                    }
                                }
                                .frame(width: 90, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(book.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(book.author)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(item: $searchTitle) { item in
            BookSearchView(viewModel: libraryVM, preselectedType: .wish, initialQuery: item.title)
        }
    }
}

// MARK: - 책 행 뷰 (공통)

struct BookRowView: View {

    let book: UserBookDto
    var showProgress: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: book.coverUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Color(.secondarySystemBackground)
                        .overlay(Image(systemName: "book.closed").foregroundStyle(.tertiary))
                }
            }
            .frame(width: 44, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if showProgress && book.totalPage > 0 {
                    ProgressView(value: book.progress)
                        .tint(.primary)
                    Text("\(Int(book.progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - 월별 막대 차트 (Swift Charts)

struct MonthlyBarChartView: View {

    let stats: [MonthlyStatsDto]

    private var maxY: Double {
        let maxVal = stats.map { Double($0.completedCount) }.max() ?? 0
        return max(maxVal * 1.2, 1)
    }

    var body: some View {
        Chart(stats, id: \.month) { item in
            BarMark(
                x: .value("월", "\(item.month)월"),
                y: .value("완독", item.completedCount)
            )
            .foregroundStyle(.primary)
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...maxY)
        .chartYAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 카테고리 도넛 차트 (Swift Charts)

struct CategoryDonutChartView: View {

    let stats: [CategoryStatsDto]

    var body: some View {
        HStack(spacing: 16) {
            Chart(Array(stats.enumerated()), id: \.offset) { idx, item in
                SectorMark(
                    angle: .value("권수", item.completedCount),
                    innerRadius: .ratio(0.55),
                    outerRadius: .ratio(0.9)
                )
                .foregroundStyle(Color.chartPalette[idx % Color.chartPalette.count])
                .annotation(position: .overlay) {
                    if item.completedCount > 0 {
                        Text("\(item.completedCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(stats.prefix(5).enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.chartPalette[idx % Color.chartPalette.count])
                            .frame(width: 8, height: 8)
                        Text(item.category)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.completedCount)권")
                            .font(.caption.weight(.medium))
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 미니 캘린더

struct MiniCalendarView: View {

    let year: Int
    let month: Int
    let books: [UserBookDto]

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let calendar = Calendar.current

    private var completedByDay: [Int: [UserBookDto]] {
        var result: [Int: [UserBookDto]] = [:]
        for book in books where book.status == .completed {
            if let end = book.endDate,
               let date = APIDate.parseDay(end) ?? APIDate.parseDateTime(end) {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                if comps.year == year, comps.month == month, let day = comps.day {
                    result[day, default: []].append(book)
                }
            }
        }
        return result
    }

    private var daysInMonth: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private var firstWeekday: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps) else { return 0 }
        return (calendar.component(.weekday, from: date) - 1 + 7) % 7
    }

    private var todayDay: Int? {
        let now = Date()
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        guard c.year == year, c.month == month else { return nil }
        return c.day
    }

    var body: some View {
        VStack(spacing: 4) {
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { idx, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(idx == 0 ? Color(.systemRed) : idx == 6 ? Color(.systemBlue) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            // 날짜 그리드
            let totalCells = firstWeekday + daysInMonth
            let rows = Int(ceil(Double(totalCells) / 7.0))
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let day = cellIndex - firstWeekday + 1
                        if day >= 1 && day <= daysInMonth {
                            DayCell(
                                day: day,
                                books: completedByDay[day] ?? [],
                                isToday: day == todayDay
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 일별 셀

private struct DayCell: View {

    let day: Int
    let books: [UserBookDto]
    let isToday: Bool

    @State private var showCompletedDialog = false

    var body: some View {
        Button {
            if !books.isEmpty { showCompletedDialog = true }
        } label: {
            ZStack(alignment: .topLeading) {
                if let firstBook = books.first {
                    AsyncImage(url: URL(string: firstBook.coverUrl)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Color(.systemGray5)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .clipped()

                    // 날짜 뱃지
                    Text("\(day)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 2))
                        .padding(2)

                    // 하단 "N권" 라벨
                    VStack {
                        Spacer()
                        Text("\(books.count)권")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                } else {
                    Text("\(day)")
                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .overlay {
                            if isToday {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(.primary, lineWidth: 1.5)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCompletedDialog) {
            CompletedBooksSheet(books: books)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - 완독 책 시트

private struct CompletedBooksSheet: View {

    let books: [UserBookDto]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(books) { book in
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: book.coverUrl)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Color(.secondarySystemBackground)
                        }
                    }
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Text(book.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("완독한 책")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DashboardTabView()
}
