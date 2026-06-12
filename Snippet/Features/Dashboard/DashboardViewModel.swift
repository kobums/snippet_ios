import SwiftUI

// MARK: - DashboardViewModel

/// 대시보드 탭 전용 ViewModel.
/// 통계/목표/스트릭/세션 데이터 로드 — 각 호출 실패 시 빈값 폴백(try?).
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: 상태

    var isLoading = false

    // 통계 탭
    var selectedYear: Int = Calendar.current.component(.year, from: .now)
    var selectedMonth: Int = Calendar.current.component(.month, from: .now)
    var monthlyBooks: [UserBookDto] = []
    var monthlyStats: [MonthlyStatsDto] = []
    var yearlyStats: [YearlyStatsDto] = []
    var categoryStats: [CategoryStatsDto] = []
    var insights: ReadingInsightsDto? = nil
    var readingGoal: ReadingGoalDto = .empty()
    var streak: StreakDto = .empty

    // 진행 탭
    var allProgressBooks: [UserBookDto] = []
    var selectedProgressStatus: BookStatus = .reading

    // 서재 탭
    var libraryBooks: [UserBookDto] = []
    var librarySearchQuery: String = ""

    // MARK: 서비스

    private let userBookService = UserBookService()
    private let statsService = StatsService()
    private let goalService = ReadingGoalService()
    private let sessionService = ReadingSessionService()

    // MARK: 공개 메서드

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMonthlyData() }
            group.addTask { await self.loadStatsData() }
            group.addTask { await self.loadGoal() }
            group.addTask { await self.loadStreak() }
            group.addTask { await self.loadProgressBooks() }
            group.addTask { await self.loadLibraryBooks() }
        }
    }

    func refreshStats() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMonthlyData() }
            group.addTask { await self.loadStatsData() }
            group.addTask { await self.loadGoal() }
            group.addTask { await self.loadStreak() }
        }
    }

    func refreshProgress() async {
        await loadProgressBooks()
    }

    func refreshLibrary() async {
        await loadLibraryBooks()
    }

    func changeMonth(year: Int, month: Int) async {
        selectedYear = year
        selectedMonth = month
        await loadMonthlyData()
    }

    func updateGoal(targetBooks: Int) async {
        let year = Calendar.current.component(.year, from: .now)
        if let updated = try? await goalService.update(year: year, targetBooks: targetBooks) {
            readingGoal = updated
        }
    }

    // MARK: 파생 계산

    /// 이번 달 완독 책
    var completedBooksThisMonth: [UserBookDto] {
        monthlyBooks.filter { $0.status == .completed }
    }

    /// 이번 달 총 페이지 (완독 책 기준)
    var totalPagesThisMonth: Int {
        completedBooksThisMonth.reduce(0) { $0 + $1.totalPage }
    }

    /// 진행 탭 필터 결과
    var filteredProgressBooks: [UserBookDto] {
        allProgressBooks.filter { $0.status == selectedProgressStatus }
    }

    /// 서재 탭 검색 결과
    var filteredLibraryBooks: [UserBookDto] {
        guard !librarySearchQuery.isEmpty else { return libraryBooks }
        let q = librarySearchQuery.lowercased()
        return libraryBooks.filter {
            $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
        }
    }

    // MARK: 비공개 로드 메서드

    private func loadMonthlyData() async {
        let books = try? await userBookService.fetchMonthly(year: selectedYear, month: selectedMonth)
        monthlyBooks = books ?? []
    }

    private func loadStatsData() async {
        async let monthly = try? statsService.monthly(year: selectedYear)
        async let yearly = try? statsService.yearly()
        async let category = try? statsService.category(year: selectedYear)
        async let ins = try? statsService.insights(year: selectedYear)
        monthlyStats = await monthly ?? []
        yearlyStats = await yearly ?? []
        categoryStats = await category ?? []
        insights = await ins
    }

    private func loadGoal() async {
        let year = Calendar.current.component(.year, from: .now)
        readingGoal = (try? await goalService.fetch(year: year)) ?? .empty(year: year)
    }

    private func loadStreak() async {
        streak = (try? await sessionService.streak()) ?? .empty
    }

    private func loadProgressBooks() async {
        let books = try? await userBookService.fetchProgress()
        allProgressBooks = books ?? []
    }

    private func loadLibraryBooks() async {
        let books = try? await userBookService.fetchPaged(page: 0, size: 50)
        libraryBooks = books ?? []
    }
}
