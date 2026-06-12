import SwiftUI

// MARK: - LibraryViewModel

/// 서재 탭 전용 ViewModel.
/// 소장(have)/대출(borrow)/위시(wish) 목록, 책 검색(알라딘), 인기 도서,
/// 책 추가·상태 변경·삭제, 책별 기록·세션(책 상세용).
@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - 서재 목록 상태 (탭별 독립)

    var haveBooks: [UserBookDto] = []
    var borrowBooks: [UserBookDto] = []
    var wishBooks: [UserBookDto] = []

    var isLoadingHave = false
    var isLoadingBorrow = false
    var isLoadingWish = false

    var haveError: String? = nil
    var borrowError: String? = nil
    var wishError: String? = nil

    // 탭별 검색어
    var haveSearchQuery = ""
    var borrowSearchQuery = ""
    var wishSearchQuery = ""

    // 무한 스크롤 페이지
    private var havePage = 0
    private var borrowPage = 0
    private var wishPage = 0
    private let pageSize = 20

    var hasMoreHave = true
    var hasMoreBorrow = true
    var hasMoreWish = true

    // MARK: - 책 검색 상태

    var searchQuery = ""
    var searchResults: [BookSearchDto] = []
    var isSearching = false
    var searchError: String? = nil
    var searchPage = 1
    var hasMoreSearchResults = true
    var isLoadingMoreSearch = false

    // MARK: - 인기 도서 상태

    var popularBooks: [PopularBookDto] = []
    var isLoadingPopular = false
    var popularError: String? = nil
    var popularQuery = PopularBooksQuery()
    var popularPage = 1
    var hasMorePopular = true

    // MARK: - 책 상세용 (기록/세션)

    var bookRecords: [RecordDto] = []
    var bookSessions: [ReadingSessionDto] = []
    var isLoadingBookRecords = false
    var isLoadingBookSessions = false

    // MARK: - 서비스

    private let userBookService = UserBookService()
    private let bookService = BookService()
    private let recordService = RecordService()
    private let sessionService = ReadingSessionService()

    // MARK: - 필터링 계산 (검색어 적용)

    var filteredHaveBooks: [UserBookDto] {
        filter(books: haveBooks, query: haveSearchQuery)
    }

    var filteredBorrowBooks: [UserBookDto] {
        filter(books: borrowBooks, query: borrowSearchQuery)
    }

    var filteredWishBooks: [UserBookDto] {
        filter(books: wishBooks, query: wishSearchQuery)
    }

    private func filter(books: [UserBookDto], query: String) -> [UserBookDto] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return books }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.author.localizedCaseInsensitiveContains(q)
        }
    }

    // MARK: - 목록 로드 (전체 재로드)

    /// 탭별 페이지네이션 로드 공통 구현. 상태 프로퍼티는 key path로 주입받아
    /// 소장/대출/위시 세 탭이 한 본문을 공유한다.
    private func loadTab(
        type: BookType,
        books: ReferenceWritableKeyPath<LibraryViewModel, [UserBookDto]>,
        page: ReferenceWritableKeyPath<LibraryViewModel, Int>,
        hasMore: ReferenceWritableKeyPath<LibraryViewModel, Bool>,
        isLoading: ReferenceWritableKeyPath<LibraryViewModel, Bool>,
        error: ReferenceWritableKeyPath<LibraryViewModel, String?>,
        errorMessage: String,
        refresh: Bool
    ) async {
        if refresh {
            self[keyPath: page] = 0
            self[keyPath: books] = []
            self[keyPath: hasMore] = true
        }
        guard self[keyPath: hasMore] else { return }
        self[keyPath: isLoading] = true
        self[keyPath: error] = nil
        defer { self[keyPath: isLoading] = false }

        let result = try? await userBookService.fetchPaged(page: self[keyPath: page], size: pageSize)
        let raw = result ?? []
        let filtered = raw.filter { $0.type == type }
        if self[keyPath: page] == 0 {
            self[keyPath: books] = filtered
        } else {
            self[keyPath: books].append(contentsOf: filtered)
        }
        // hasMore/page 전진은 API 페이지(raw)의 채움 여부로 판단해야 한다.
        // 타입 필터링된 개수로 판단하면 page 0 이후 페이지네이션이 멈춘다.
        if raw.count < pageSize { self[keyPath: hasMore] = false }
        else { self[keyPath: page] += 1 }
        if result == nil { self[keyPath: error] = errorMessage }
    }

    func loadHave(refresh: Bool = false) async {
        await loadTab(type: .have, books: \.haveBooks, page: \.havePage,
                      hasMore: \.hasMoreHave, isLoading: \.isLoadingHave, error: \.haveError,
                      errorMessage: "소장 도서를 불러올 수 없습니다", refresh: refresh)
    }

    func loadBorrow(refresh: Bool = false) async {
        await loadTab(type: .borrow, books: \.borrowBooks, page: \.borrowPage,
                      hasMore: \.hasMoreBorrow, isLoading: \.isLoadingBorrow, error: \.borrowError,
                      errorMessage: "대출 도서를 불러올 수 없습니다", refresh: refresh)
    }

    func loadWish(refresh: Bool = false) async {
        await loadTab(type: .wish, books: \.wishBooks, page: \.wishPage,
                      hasMore: \.hasMoreWish, isLoading: \.isLoadingWish, error: \.wishError,
                      errorMessage: "위시리스트를 불러올 수 없습니다", refresh: refresh)
    }

    /// 서재 진입 시 전체 탭 초기 로드. `/userbooks/all` 한 페이지를 한 번만 받아
    /// 세 탭으로 분배한다(같은 엔드포인트를 3번 호출하던 중복 제거).
    func loadAllTabs() async {
        havePage = 0; borrowPage = 0; wishPage = 0
        hasMoreHave = true; hasMoreBorrow = true; hasMoreWish = true
        isLoadingHave = true; isLoadingBorrow = true; isLoadingWish = true
        haveError = nil; borrowError = nil; wishError = nil
        defer { isLoadingHave = false; isLoadingBorrow = false; isLoadingWish = false }

        let result = try? await userBookService.fetchPaged(page: 0, size: pageSize)
        let raw = result ?? []
        haveBooks = raw.filter { $0.type == .have }
        borrowBooks = raw.filter { $0.type == .borrow }
        wishBooks = raw.filter { $0.type == .wish }
        if raw.count < pageSize {
            hasMoreHave = false; hasMoreBorrow = false; hasMoreWish = false
        } else {
            havePage = 1; borrowPage = 1; wishPage = 1
        }
        if result == nil {
            let message = "서재를 불러올 수 없습니다"
            haveError = message; borrowError = message; wishError = message
        }
    }

    func loadMoreIfNeeded(for type: BookType) async {
        switch type {
        case .have:
            guard hasMoreHave, !isLoadingHave else { return }
            await loadHave()
        case .borrow:
            guard hasMoreBorrow, !isLoadingBorrow else { return }
            await loadBorrow()
        case .wish:
            guard hasMoreWish, !isLoadingWish else { return }
            await loadWish()
        case .returned:
            break
        }
    }

    // MARK: - 책 추가

    @discardableResult
    func addBook(_ request: LibraryAddRequest) async -> Bool {
        _ = try? await userBookService.add(request)
        await loadAllTabs()
        return true
    }

    // MARK: - 상태·진행도 변경

    @discardableResult
    func updateBook(id: Int, request: UserBookUpdateRequest) async -> Bool {
        let result = try? await userBookService.update(id: id, request)
        if result != nil {
            await loadAllTabs()
            return true
        }
        await loadAllTabs()
        return false
    }

    // MARK: - 삭제

    @discardableResult
    func deleteBook(id: Int) async -> Bool {
        _ = try? await userBookService.delete(id: id)
        await loadAllTabs()
        return true
    }

    // MARK: - 책 검색 (알라딘)

    func searchBooks(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        searchQuery = trimmed
        searchPage = 1
        hasMoreSearchResults = true
        isSearching = true
        searchError = nil
        defer { isSearching = false }

        let result = try? await bookService.search(query: trimmed, page: 1)
        searchResults = result ?? []
        if (result ?? []).count < 10 { hasMoreSearchResults = false }
        if result == nil { searchError = "검색 결과를 불러올 수 없습니다" }
    }

    func loadMoreSearchResults() async {
        guard hasMoreSearchResults, !isLoadingMoreSearch else { return }
        isLoadingMoreSearch = true
        defer { isLoadingMoreSearch = false }
        let nextPage = searchPage + 1
        let result = try? await bookService.search(query: searchQuery, page: nextPage)
        let items = result ?? []
        if items.count < 10 { hasMoreSearchResults = false }
        if !items.isEmpty {
            searchResults.append(contentsOf: items)
            searchPage = nextPage
        }
    }

    // MARK: - 인기 도서

    /// 진행 중인 인기 도서 로드 Task — 동시 호출(필터 변경 vs 무한스크롤) 직렬화용.
    private var popularLoadTask: Task<Void, Never>?

    func loadPopular(refresh: Bool = false) async {
        // 직전 로드가 끝난 뒤 순차 실행해 popularPage/popularBooks 상태 경쟁을 막는다.
        let previous = popularLoadTask
        let task = Task { @MainActor [weak self] in
            await previous?.value
            await self?.performLoadPopular(refresh: refresh)
        }
        popularLoadTask = task
        await task.value
    }

    private func performLoadPopular(refresh: Bool) async {
        if refresh {
            popularPage = 1
            popularBooks = []
            hasMorePopular = true
            popularQuery.pageNo = 1
        }
        isLoadingPopular = true
        popularError = nil
        defer { isLoadingPopular = false }

        let result = try? await bookService.popular(popularQuery)
        let books = result ?? []
        if popularPage == 1 {
            popularBooks = books
        } else {
            popularBooks.append(contentsOf: books)
        }
        if books.count < popularQuery.pageSize { hasMorePopular = false }
        else {
            popularPage += 1
            popularQuery.pageNo = popularPage
        }
        if result == nil { popularError = "인기 도서를 불러올 수 없습니다" }
    }

    func loadMorePopular() async {
        guard hasMorePopular, !isLoadingPopular else { return }
        await loadPopular()
    }

    func applyPopularFilter(kdc: String? = nil, age: String? = nil, gender: String? = nil) async {
        popularQuery.kdc = kdc
        popularQuery.age = age
        popularQuery.gender = gender
        await loadPopular(refresh: true)
    }

    // MARK: - 책 상세용 기록/세션

    func loadBookRecords(bookId: Int) async {
        isLoadingBookRecords = true
        defer { isLoadingBookRecords = false }
        bookRecords = (try? await recordService.fetchByBook(bookId: bookId)) ?? []
    }

    func loadBookSessions(userBookId: Int) async {
        isLoadingBookSessions = true
        defer { isLoadingBookSessions = false }
        bookSessions = (try? await sessionService.fetchByBook(userBookId: userBookId)) ?? []
    }
}
