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
    var recommendedBooks: [BookRecommendDto] = []

    // 일별 읽은 페이지 (선택한 년/월)
    var dailyPages: DailyPagesSummary? = nil
    var dailyPagesError: String? = nil

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
    private let bookService = BookService()
    private let readingLogService = ReadingLogService()

    // MARK: 공개 메서드

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMonthlyData() }
            group.addTask { await self.loadStatsData() }
            group.addTask { await self.loadDailyPages() }
            group.addTask { await self.loadGoal() }
            group.addTask { await self.loadStreak() }
            group.addTask { await self.loadProgressBooks() }
            group.addTask { await self.loadLibraryBooks() }
            group.addTask { await self.loadRecommendations() }
        }
    }

    func refreshStats() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMonthlyData() }
            group.addTask { await self.loadStatsData() }
            group.addTask { await self.loadDailyPages() }
            group.addTask { await self.loadGoal() }
            group.addTask { await self.loadStreak() }
            group.addTask { await self.loadRecommendations() }
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
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMonthlyData() }
            group.addTask { await self.loadDailyPages() }
        }
    }

    /// 연도 변경 — 월 데이터와 함께 연도 스코프 통계(월별 차트/카테고리/인사이트)도 갱신.
    /// (loadMonthlyData만 호출하면 월별 완독 현황·카테고리 도넛이 이전 연도 데이터로 남는다)
    func changeYear() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMonthlyData() }
            group.addTask { await self.loadStatsData() }
            group.addTask { await self.loadDailyPages() }
        }
    }

    /// 일별 읽은 페이지만 다시 불러온다 (에러 상태의 "다시 시도").
    func retryDailyPages() async {
        await loadDailyPages()
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

    // 월 이동 연타 시 늦게 도착한 이전 요청 응답이 현재 화면을 덮어쓰지 않도록
    // 세대 토큰으로 최신 요청만 상태에 반영한다. (@MainActor라 증가/비교는 직렬화됨)
    private var monthlyLoadID = 0
    private var statsLoadID = 0
    private var dailyPagesLoadID = 0

    private func loadMonthlyData() async {
        monthlyLoadID += 1
        let loadID = monthlyLoadID
        let books = try? await userBookService.fetchMonthly(year: selectedYear, month: selectedMonth)
        guard loadID == monthlyLoadID else { return }
        monthlyBooks = books ?? []
    }

    private func loadStatsData() async {
        statsLoadID += 1
        let loadID = statsLoadID
        async let monthly = try? statsService.monthly(year: selectedYear)
        async let yearly = try? statsService.yearly()
        async let category = try? statsService.category(year: selectedYear)
        async let ins = try? statsService.insights(year: selectedYear)
        let (m, y, c, i) = await (monthly, yearly, category, ins)
        guard loadID == statsLoadID else { return }
        monthlyStats = m ?? []
        yearlyStats = y ?? []
        categoryStats = c ?? []
        insights = i
    }

    /// GET /readinglogs/daily — 다른 카드와 달리 빈값 폴백 대신 에러를 노출한다
    /// (0쪽 차트가 "안 읽었다"로 오해되지 않도록).
    private func loadDailyPages() async {
        dailyPagesLoadID += 1
        let loadID = dailyPagesLoadID
        let year = selectedYear
        let month = selectedMonth
        dailyPagesError = nil
        // 다른 달로 이동했으면 이전 달 데이터를 보이지 않게 비운다 (같은 달 새로고침은 유지).
        if let current = dailyPages, current.year != year || current.month != month {
            dailyPages = nil
        }
        do {
            let logs = try await readingLogService.daily(year: year, month: month)
            guard loadID == dailyPagesLoadID else { return }
            dailyPages = DailyPagesSummary(year: year, month: month, logs: logs)
        } catch {
            guard loadID == dailyPagesLoadID else { return }
            // pull-to-refresh 취소 등 사용자가 의도한 취소는 에러로 보이지 않는다.
            // (APIClient가 URLError를 APIError.network로 감싸므로 Task 취소 여부로 판별)
            let isCancellation = Task.isCancelled || error is CancellationError
            if !isCancellation {
                dailyPagesError = APIError.wrap(error).userMessage
            }
        }
    }

    private func loadGoal() async {
        let year = Calendar.current.component(.year, from: .now)
        readingGoal = (try? await goalService.fetch(year: year)) ?? .empty(year: year)
    }

    private func loadStreak() async {
        streak = (try? await sessionService.streak()) ?? .empty
    }

    /// GET /books/recommend — 실패 시 빈 배열 폴백 (문서 §3.6).
    func loadRecommendations() async {
        recommendedBooks = (try? await bookService.recommend()) ?? []
    }

    private func loadProgressBooks() async {
        let books = try? await userBookService.fetchProgress()
        allProgressBooks = books ?? []
    }

    /// 서재 탭이 전량 로드됐는지 — 검색 필터는 전량 위에서만 정확하다.
    private var isLibraryFullyLoaded = false
    private var isLoadingLibraryRest = false
    private let libraryPageSize = 50

    private func loadLibraryBooks() async {
        isLibraryFullyLoaded = false
        let books = try? await userBookService.fetchPaged(page: 0, size: libraryPageSize)
        libraryBooks = books ?? []
        if let books, books.count < libraryPageSize { isLibraryFullyLoaded = true }
    }

    /// 검색어 입력 시 남은 페이지를 전부 로드한다.
    /// 첫 페이지에만 필터가 걸리면 뒤 페이지의 책이 "검색 결과 없음"으로 나오기 때문.
    func ensureLibraryFullyLoadedForSearch() async {
        guard !librarySearchQuery.trimmingCharacters(in: .whitespaces).isEmpty,
              !isLibraryFullyLoaded, !isLoadingLibraryRest else { return }
        isLoadingLibraryRest = true
        defer { isLoadingLibraryRest = false }

        var page = 1
        while true {
            // 에러 시 중단 — 다음 검색어 입력에서 재시도된다.
            guard let books = try? await userBookService.fetchPaged(page: page, size: libraryPageSize) else { return }
            // refresh와 겹쳐도 중복 행이 생기지 않도록 id 기준 dedupe
            let known = Set(libraryBooks.map(\.id))
            libraryBooks.append(contentsOf: books.filter { !known.contains($0.id) })
            if books.count < libraryPageSize {
                isLibraryFullyLoaded = true
                return
            }
            page += 1
        }
    }
}
