import SwiftUI

// MARK: - BookSearchView

/// 책 검색/추가 화면.
/// 알라딘 검색 → 결과 탭 → AddBookSheet로 서재 추가.
struct BookSearchView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LibraryViewModel
    var preselectedType: BookType = .have

    /// 진입 즉시 바코드 스캐너를 띄울지 여부(서재 탭의 바코드 버튼에서 true).
    var autoStartScan: Bool = false

    /// 진입 시 미리 채울 검색어(추천 도서 탭에서 책 제목 주입).
    var initialQuery: String = ""

    @State private var query = ""
    @State private var selectedBook: BookSearchDto? = nil
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var showScanner = false
    @State private var didAutoStart = false

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    initialState
                } else if viewModel.isSearching {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let error = viewModel.searchError, viewModel.searchResults.isEmpty {
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: "검색 오류",
                        message: error,
                        actionTitle: "다시 시도",
                        action: { Task { await viewModel.searchBooks(query: query) } }
                    )
                } else if viewModel.searchResults.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "검색 결과가 없습니다",
                        message: "다른 검색어를 시도해보세요"
                    )
                } else {
                    resultsList
                }
            }
            .navigationTitle("책 검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 바코드 스캔 → ISBN 인식 후 검색어로 주입
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "책 제목, 저자, ISBN 검색")
            .onChange(of: query) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                    guard !Task.isCancelled else { return }
                    await viewModel.searchBooks(query: newValue)
                }
            }
            .sheet(item: $selectedBook) { book in
                AddBookSheet(
                    book: book,
                    preselectedType: preselectedType,
                    onAdd: { request in
                        Task {
                            _ = await viewModel.addBook(request)
                        }
                        dismiss()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in
                    showScanner = false
                    query = code // .onChange(of: query)가 디바운스 검색을 트리거
                }
            }
            .onAppear {
                if autoStartScan && !didAutoStart {
                    didAutoStart = true
                    showScanner = true
                }
                if !initialQuery.isEmpty && query.isEmpty {
                    query = initialQuery // .onChange(of: query)가 디바운스 검색을 트리거
                }
            }
        }
    }

    private var initialState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("책을 검색해보세요")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var resultsList: some View {
        List {
            ForEach(viewModel.searchResults, id: \.isbn) { book in
                BookSearchResultRow(book: book)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        selectedBook = book
                    }
                    .onAppear {
                        if book == viewModel.searchResults.last {
                            Task { await viewModel.loadMoreSearchResults() }
                        }
                    }
            }
            if viewModel.isLoadingMoreSearch {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - BookSearchResultRow

private struct BookSearchResultRow: View {
    let book: BookSearchDto

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(urlString: book.coverUrl, size: .large)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if !book.publisher.isEmpty {
                        Text(book.publisher)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if !book.pubDate.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(String(book.pubDate.prefix(10)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(Color.accentText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AddBookSheet

/// 책 추가 바텀시트 — 분류·상태 선택 후 서재 추가.
struct AddBookSheet: View {
    let book: BookSearchDto
    var preselectedType: BookType = .have
    let onAdd: (LibraryAddRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: BookType
    @State private var selectedStatus: BookStatus = .waiting

    init(book: BookSearchDto, preselectedType: BookType = .have, onAdd: @escaping (LibraryAddRequest) -> Void) {
        self.book = book
        self.preselectedType = preselectedType
        self.onAdd = onAdd
        _selectedType = State(initialValue: preselectedType == .wish ? .wish : (preselectedType == .borrow ? .borrow : .have))
    }

    private var isoNow: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private var dateStr: String {
        APIDate.dayString()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 책 정보 행
                    HStack(spacing: 12) {
                        BookCoverView(urlString: book.coverUrl, size: .large)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(3)
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    // 분류 선택
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
                            if newType == .wish {
                                selectedStatus = .none
                            } else if selectedStatus == .none {
                                selectedStatus = .waiting
                            }
                        }
                    }

                    // 상태 선택 (위시 아님)
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

                    // 추가 버튼
                    Button {
                        let request = LibraryAddRequest(
                            title: book.title,
                            author: book.author,
                            publisher: book.publisher,
                            pubDate: book.pubDate,
                            isbn: book.isbn,
                            coverUrl: book.coverUrl,
                            totalPage: book.totalPage ?? 0,
                            type: selectedType,
                            status: selectedType == .wish ? .none : selectedStatus,
                            readPage: 0,
                            startDate: selectedStatus == .reading || selectedStatus == .completed ? dateStr : "",
                            endDate: selectedStatus == .completed ? dateStr : "",
                            createDate: dateStr
                        )
                        onAdd(request)
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

// MARK: - BookSearchDto + Identifiable

extension BookSearchDto: Identifiable {
    public var id: String { isbn.isEmpty ? title : isbn }
}

#Preview {
    BookSearchView(viewModel: LibraryViewModel())
}
