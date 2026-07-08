import SwiftUI

// MARK: - LibraryTabView

/// 서재 탭 — 소장/대출/위시 3서브탭 + 책 검색/인기도서 진입.
struct LibraryTabView: View {

    @State private var viewModel = LibraryViewModel()
    @State private var selectedTab: BookType = .have
    @State private var showBookSearch = false
    @State private var showPopularBooks = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top + 64
                let bottomInset = proxy.safeAreaInsets.bottom + 8

                ZStack(alignment: .top) {
                    libraryPages
                        .contentMargins(.top, topInset, for: .scrollContent)
                        .contentMargins(.bottom, bottomInset, for: .scrollContent)
                        .ignoresSafeArea(edges: [.top, .bottom])

                    floatingBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBookSearch) {
                BookSearchView(viewModel: viewModel, preselectedType: selectedTab)
            }
            .sheet(isPresented: $showPopularBooks) {
                PopularBooksView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadAllTabs()
        }
    }

    // MARK: - 플로팅 바 — [탭바] [인기] [+] 한 줄

    private var floatingBar: some View {
        HStack(spacing: 10) {
            FloatingSubTabBar(
                tabs: [
                    (BookType.have, "소장"),
                    (BookType.borrow, "대출"),
                    (BookType.wish, "위시"),
                ],
                selection: $selectedTab
            )

            Button {
                showPopularBooks = true
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 17))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button {
                showBookSearch = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        .padding(.top, 4)
        .padding(.horizontal, 12)
    }

    private var libraryPages: some View {
                ZStack {
                    LibrarySubTabView(
                        type: .have,
                        books: viewModel.filteredHaveBooks,
                        isLoading: viewModel.isLoadingHave,
                        error: viewModel.haveError,
                        onRefresh: { await viewModel.loadHave(refresh: true) },
                        onLoadMore: { await viewModel.loadMoreIfNeeded(for: .have) },
                        onDelete: { id in
                            _ = await viewModel.deleteBook(id: id)
                        },
                        onUpdate: { id, req in
                            _ = await viewModel.updateBook(id: id, request: req)
                        },
                        viewModel: viewModel
                    )
                    .opacity(selectedTab == .have ? 1 : 0)
                    .allowsHitTesting(selectedTab == .have)

                    LibrarySubTabView(
                        type: .borrow,
                        books: viewModel.filteredBorrowBooks,
                        isLoading: viewModel.isLoadingBorrow,
                        error: viewModel.borrowError,
                        onRefresh: { await viewModel.loadBorrow(refresh: true) },
                        onLoadMore: { await viewModel.loadMoreIfNeeded(for: .borrow) },
                        onDelete: { id in
                            _ = await viewModel.deleteBook(id: id)
                        },
                        onUpdate: { id, req in
                            _ = await viewModel.updateBook(id: id, request: req)
                        },
                        viewModel: viewModel
                    )
                    .opacity(selectedTab == .borrow ? 1 : 0)
                    .allowsHitTesting(selectedTab == .borrow)

                    LibrarySubTabView(
                        type: .wish,
                        books: viewModel.filteredWishBooks,
                        isLoading: viewModel.isLoadingWish,
                        error: viewModel.wishError,
                        onRefresh: { await viewModel.loadWish(refresh: true) },
                        onLoadMore: { await viewModel.loadMoreIfNeeded(for: .wish) },
                        onDelete: { id in
                            _ = await viewModel.deleteBook(id: id)
                        },
                        onUpdate: { id, req in
                            _ = await viewModel.updateBook(id: id, request: req)
                        },
                        viewModel: viewModel
                    )
                    .opacity(selectedTab == .wish ? 1 : 0)
                    .allowsHitTesting(selectedTab == .wish)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

// MARK: - LibrarySubTabView

/// 서재 서브탭 (소장/대출/위시 공통).
private struct LibrarySubTabView: View {
    let type: BookType
    let books: [UserBookDto]
    let isLoading: Bool
    let error: String?
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let onDelete: (Int) async -> Void
    let onUpdate: (Int, UserBookUpdateRequest) async -> Void
    let viewModel: LibraryViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var emptyTitle: String {
        switch type {
        case .have: return "소장한 책이 없습니다"
        case .borrow: return "빌린 책이 없습니다"
        case .wish: return "위시리스트가 비어있습니다"
        case .returned: return "반납한 책이 없습니다"
        }
    }

    var emptyMessage: String {
        switch type {
        case .have: return "첫 책을 추가해보세요!"
        case .borrow: return "빌린 책을 추가해보세요"
        case .wish: return "읽고 싶은 책을 추가해보세요"
        case .returned: return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && books.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error, books.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "오류가 발생했습니다",
                    message: error,
                    actionTitle: "다시 시도",
                    action: { Task { await onRefresh() } }
                )
                Spacer()
            } else if books.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: emptyTitle,
                    message: emptyMessage
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(books) { book in
                            NavigationLink {
                                BookDetailView(userBook: book, viewModel: viewModel)
                            } label: {
                                BookGridCard(
                                    book: book,
                                    onUpdate: { req in
                                        Task { await onUpdate(book.id, req) }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if book.id == books.last?.id {
                                    Task { await onLoadMore() }
                                }
                            }
                        }
                    }
                    .padding(16)

                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .refreshable {
                    Haptics.medium()
                    await onRefresh()
                }
            }
        }
    }
}

// MARK: - BookGridCard

/// 서재 2열 그리드 카드.
struct BookGridCard: View {
    let book: UserBookDto
    var onUpdate: ((UserBookUpdateRequest) -> Void)?

    private var statusBadgeColor: Color {
        switch book.status {
        case .waiting: return Color(.systemGray)
        case .reading: return .accentColor
        case .completed: return Color(.systemGreen)
        case .dropped: return Color(.systemOrange)
        case .none: return Color(.systemGray3)
        }
    }

    private var statusLabel: String {
        switch book.status {
        case .waiting: return "대기중"
        case .reading: return "읽는중"
        case .completed: return "완독"
        case .dropped: return "중단"
        case .none: return ""
        }
    }

    private var ddayBadge: (text: String, color: Color)? {
        guard book.type == .borrow, let returnDateStr = book.returnDate else { return nil }
        guard let returnDate = APIDate.parseDay(String(returnDateStr.prefix(10))) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: returnDate)
        let diff = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        if diff < 0 {
            return ("연체 \(-diff)일", Color(.systemRed))
        } else if diff <= 3 {
            return ("D-\(diff)", Color(.systemOrange))
        } else {
            return ("D-\(diff)", Color(.systemGreen))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 표지 + 상태 뱃지
            ZStack(alignment: .topTrailing) {
                // 책 표지 비율(2:3 상당)로 영역을 잡아 표지가 잘리지 않게 한다
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.72, contentMode: .fit)
                    .overlay {
                        BookCoverView(
                            urlString: book.coverUrl,
                            size: .custom(width: .infinity, height: .infinity, cornerRadius: 8)
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if book.status != .none {
                    Text(statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(book.status == .reading ? Color.onAccent : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusBadgeColor, in: RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }

                // D-day 뱃지 (대출) — 표지 우하단 오버레이
                if let dday = ddayBadge {
                    Text(dday.text)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(dday.color, in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.caption.weight(.medium))
                    // 1줄짜리 제목도 항상 2줄 높이를 차지해 카드 높이가 통일된다
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                Text(book.author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // 상태별 부가 영역 — 내용과 무관하게 고정 높이라 모든 카드 높이가 같다
                VStack(alignment: .leading, spacing: 4) {
                    // 진행률 (읽는중) — 게이지와 %를 한 줄로
                    if book.status == .reading && book.totalPage > 0 {
                        HStack(spacing: 6) {
                            ProgressView(value: book.progress)
                                .tint(.accentColor)
                                .scaleEffect(x: 1, y: 0.7)

                            Text("\(Int(book.progress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 상태 변경 버튼 (wish 아님)
                    if book.type != .wish {
                        if book.status == .waiting {
                            Button("읽기 시작") {
                                onUpdate?(.init(status: .reading))
                            }
                            .font(.caption.weight(.medium))
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(Color.onAccent)
                            .controlSize(.small)
                        } else if book.status == .reading {
                            HStack(spacing: 4) {
                                Button("완독") {
                                    onUpdate?(.init(status: .completed))
                                }
                                .font(.caption2.weight(.medium))
                                .buttonStyle(.borderedProminent)
                                .foregroundStyle(Color.onAccent)
                                .controlSize(.mini)

                                Button("중단") {
                                    onUpdate?(.init(status: .dropped))
                                }
                                .font(.caption2.weight(.medium))
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .tint(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(height: 52, alignment: .top)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    LibraryTabView()
}
