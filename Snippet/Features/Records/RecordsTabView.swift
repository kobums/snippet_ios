import SwiftUI

// MARK: - RecordsTabView

/// 독서 기록 탭 루트 — 스니펫 | 독서일기 | 리뷰 | 독서세션 서브탭.
struct RecordsTabView: View {

    @State private var vm = RecordsViewModel()
    @State private var selectedSubTab: SubTab = .snippet
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
                    ZStack {
                        RecordListView(vm: vm, type: .snippet)
                            .opacity(selectedSubTab == .snippet ? 1 : 0)
                            .allowsHitTesting(selectedSubTab == .snippet)
                        RecordListView(vm: vm, type: .diary)
                            .opacity(selectedSubTab == .diary ? 1 : 0)
                            .allowsHitTesting(selectedSubTab == .diary)
                        RecordListView(vm: vm, type: .review)
                            .opacity(selectedSubTab == .review ? 1 : 0)
                            .allowsHitTesting(selectedSubTab == .review)
                        SessionsListView(vm: vm)
                            .opacity(selectedSubTab == .session ? 1 : 0)
                            .allowsHitTesting(selectedSubTab == .session)
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
                    .contentMargins(.top, topInset, for: .scrollContent)
                    .contentMargins(.bottom, bottomInset, for: .scrollContent)
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
                selection: $selectedSubTab
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

    @State private var editingRecord: RecordDto? = nil
    @State private var deleteTarget: RecordDto? = nil
    @State private var showDeleteAlert = false

    private var grouped: [(groupId: Int, bookTitle: String, records: [RecordDto])] {
        vm.groupedRecords(for: type)
    }

    var body: some View {
        Group {
            if vm.isLoadingRecords {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if grouped.isEmpty {
                EmptyStateView(
                    systemImage: "note.text",
                    title: "아직 기록이 없습니다",
                    message: "첫 기록을 추가해보세요!"
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

                    // 책 제목별 그룹
                    ForEach(grouped, id: \.groupId) { group in
                        Section {
                            // 책 제목 행
                            Text(group.bookTitle)
                                .font(.body.weight(.semibold))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)

                            // 기록 카드 목록
                            ForEach(group.records) { record in
                                RecordCardView(record: record)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .onTapGesture { editingRecord = record }
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
        .alert("이 기록을 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                if let target = deleteTarget {
                    Task {
                        await vm.deleteRecord(id: target.id)
                        deleteTarget = nil
                    }
                }
            }
            Button("취소", role: .cancel) {
                deleteTarget = nil
            }
        }
    }
}
