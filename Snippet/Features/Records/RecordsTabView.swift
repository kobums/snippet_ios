import SwiftUI

// MARK: - RecordsTabView

/// 독서 기록 탭 루트 — 스니펫 | 독서일기 | 리뷰 | 독서세션 서브탭.
struct RecordsTabView: View {

    @State private var vm = RecordsViewModel()
    @State private var selectedSubTab: SubTab = .snippet
    /// 콘텐츠 전환 방향 — 새로 선택한 탭이 오른쪽이면 오른쪽에서 밀려 들어온다(공간 일관성).
    @State private var transitionEdge: Edge = .trailing
    @State private var showAddRecord = false
    @State private var showMonthPicker = false

    // 기록 추가 시 책 선택 피커에 쓸 서재 목록
    @State private var libraryBooks: [UserBookDto] = []
    @State private var isLoadingBooks = false
    private let userBookService = UserBookService()

    enum SubTab: Int, CaseIterable {
        case snippet, diary, review, session

        var title: String {
            switch self {
            case .snippet: "스니펫"
            case .diary:   "일기"
            case .review:  "리뷰"
            case .session: "세션"
            }
        }

        var recordType: RecordType? {
            switch self {
            case .snippet: .snippet
            case .diary:   .diary
            case .review:  .review
            case .session: nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top + 64
                let bottomInset = proxy.safeAreaInsets.bottom + 8

                ZStack(alignment: .top) {
                    // 탭 순서 방향으로 밀려 들어오는 전환 — 대시보드·통계 상세와 같은 문법(공간 일관성).
                    // 한 번에 한 뷰만 존재하므로 투명한 List가 터치를 가로채는 문제도 원천 차단된다.
                    // contentMargins는 각 리스트의 스크롤 뷰에 직접 적용한다 (대시보드와 동일).
                    // 이 컨테이너에 걸면 environment로 내부 시트까지 전파되어 시트 상단에 공백이 생긴다.
                    ZStack {
                        switch selectedSubTab {
                        case .snippet:
                            RecordListView(vm: vm, type: .snippet, topInset: topInset, bottomInset: bottomInset) { Task { await openAddRecord() } }
                                .transition(.push(from: transitionEdge))
                        case .diary:
                            RecordListView(vm: vm, type: .diary, topInset: topInset, bottomInset: bottomInset) { Task { await openAddRecord() } }
                                .transition(.push(from: transitionEdge))
                        case .review:
                            RecordListView(vm: vm, type: .review, topInset: topInset, bottomInset: bottomInset) { Task { await openAddRecord() } }
                                .transition(.push(from: transitionEdge))
                        case .session:
                            SessionsListView(vm: vm, topInset: topInset, bottomInset: bottomInset)
                                .transition(.push(from: transitionEdge))
                        }
                    }
                    .ignoresSafeArea(edges: [.top, .bottom])

                    floatingBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: vm.selectedYear) { _, _ in
                Task { await vm.changeMonth(year: vm.selectedYear, month: vm.selectedMonth) }
            }
            .onChange(of: vm.selectedMonth) { _, _ in
                Task { await vm.changeMonth(year: vm.selectedYear, month: vm.selectedMonth) }
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthYearPickerSheet(year: $vm.selectedYear, month: $vm.selectedMonth)
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddRecord, onDismiss: {
                Task { await vm.loadRecords() }
            }) {
                AddRecordView(
                    initialType: selectedSubTab.recordType ?? .snippet,
                    books: libraryBooks,
                    onSaved: { showAddRecord = false }
                )
            }
            .task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await vm.loadRecords() }
                    group.addTask { await vm.loadSessions() }
                }
            }
        }
    }

    // MARK: - 플로팅 바 — [탭바] [년월] [+] 한 줄

    private var floatingBar: some View {
        HStack(spacing: 10) {
            FloatingSubTabBar(
                tabs: SubTab.allCases.map { ($0, $0.title) },
                selection: Binding(
                    get: { selectedSubTab },
                    set: { newTab in
                        guard newTab != selectedSubTab else { return }
                        transitionEdge = newTab.rawValue > selectedSubTab.rawValue ? .trailing : .leading
                        Haptics.selection()
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedSubTab = newTab
                        }
                    }
                )
            )

            // 년월·추가 버튼: 스니펫/일기/리뷰 탭에서만 노출
            if selectedSubTab != .session {
                Button {
                    showMonthPicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 17))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))

                Button {
                    Task { await openAddRecord() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(isLoadingBooks)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        // 필 이동과 동일한 스프링으로 바 전체 레이아웃을 함께 움직인다
        // (아이콘이 즉시 사라지면 필이 캡슐 밖으로 삐져나오는 버그 방지)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedSubTab)
        .padding(.top, 4)
        .padding(.horizontal, 12)
    }

    /// "+" 탭 시 서재 책 목록을 받아온 뒤 책 선택 피커가 있는 기록 추가 화면을 연다.
    private func openAddRecord() async {
        isLoadingBooks = true
        defer { isLoadingBooks = false }
        let books = (try? await userBookService.fetchPaged(page: 0, size: 200)) ?? []
        libraryBooks = books
        showAddRecord = true
    }
}

// MARK: - RecordListView

/// 스니펫 / 독서일기 / 리뷰 공통 목록 뷰.
private struct RecordListView: View {

    @Bindable var vm: RecordsViewModel
    let type: RecordType
    /// 플로팅 바 높이만큼 스크롤 콘텐츠를 내리는 인셋 — 리스트에 직접 적용.
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    /// 빈 상태의 "기록 추가" 액션 — 플로팅 바의 +와 같은 동작.
    var onAdd: () -> Void = {}

    @State private var editingRecord: RecordDto? = nil
    @State private var deleteTarget: RecordDto? = nil
    @State private var showDeleteAlert = false
    @State private var showDeleteError = false

    // 책 그룹 헤더 → BookDetailView 이동용 (bookId → 서재 목록 매칭)
    @State private var detailBook: UserBookDto? = nil
    @State private var libraryVM = LibraryViewModel()
    private let userBookService = UserBookService()

    private var grouped: [(groupId: Int, bookTitle: String, records: [RecordDto])] {
        vm.groupedRecords(for: type)
    }

    /// 타입별로 구체적인 빈 상태 — 무엇이 없고 무엇을 하면 되는지 말해준다.
    private var emptyContent: (icon: String, title: String, message: String, action: String) {
        switch type {
        case .snippet:
            ("quote.opening", "아직 스니펫이 없어요", "마음에 남은 한 문장을 옮겨 적어보세요.", "스니펫 남기기")
        case .diary:
            ("book.pages", "아직 독서 일기가 없어요", "오늘 읽으며 든 생각을 남겨보세요.", "일기 쓰기")
        case .review:
            ("star.bubble", "아직 리뷰가 없어요", "완독한 책의 감상을 정리해보세요.", "리뷰 쓰기")
        }
    }

    var body: some View {
        Group {
            if vm.isLoadingRecords {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.recordsError {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "불러올 수 없습니다",
                    message: error,
                    actionTitle: "다시 시도"
                ) {
                    Task { await vm.loadRecords() }
                }
            } else if grouped.isEmpty {
                EmptyStateView(
                    systemImage: emptyContent.icon,
                    title: emptyContent.title,
                    message: emptyContent.message,
                    actionTitle: emptyContent.action,
                    action: onAdd
                )
            } else {
                List {
                    // 총 건수 헤더
                    Section {
                        SectionHeaderView(title: "기록 (\(vm.records(for: type).count))")
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    // 책별 그룹 — 표지 + 세리프 제목 헤더
                    ForEach(grouped, id: \.groupId) { group in
                        Section {
                            // 그룹 헤더 탭 → 책 상세 (bookId로 서재에서 찾아 이동)
                            Button {
                                Task { await openBookDetail(bookId: group.groupId) }
                            } label: {
                                RecordBookGroupHeader(
                                    title: group.bookTitle,
                                    author: group.records.first?.bookAuthor,
                                    coverUrl: group.records.first?.bookCoverUrl,
                                    count: group.records.count
                                )
                            }
                            .buttonStyle(.pressable)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)

                            // 기록 카드 목록 — 버튼으로 감싸 터치 다운 즉시 눌림 피드백
                            ForEach(group.records) { record in
                                Button {
                                    editingRecord = record
                                } label: {
                                    RecordCardView(record: record)
                                }
                                .buttonStyle(.pressable)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteTarget = record
                                        showDeleteAlert = true
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.top, topInset, for: .scrollContent)
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .refreshable {
                    await vm.loadRecords()
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            EditRecordView(record: record, vm: vm) {
                editingRecord = nil
            }
        }
        .navigationDestination(item: $detailBook) { book in
            BookDetailView(userBook: book, viewModel: libraryVM)
        }
        .alert("이 기록을 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                if let target = deleteTarget {
                    Task {
                        if await vm.deleteRecord(id: target.id) {
                            Haptics.success()
                        } else {
                            Haptics.error()
                            showDeleteError = true
                        }
                        deleteTarget = nil
                    }
                }
            }
            Button("취소", role: .cancel) {
                deleteTarget = nil
            }
        }
        .deleteFailureAlert(isPresented: $showDeleteError)
    }

    /// 그룹 헤더의 bookId로 서재 목록에서 UserBookDto를 찾아 상세로 이동한다.
    private func openBookDetail(bookId: Int) async {
        let books = (try? await userBookService.fetchPaged(page: 0, size: 200)) ?? []
        guard let book = books.first(where: { $0.bookId == bookId }) else { return }
        detailBook = book
    }
}
