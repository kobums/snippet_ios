import SwiftUI

// MARK: - RecordsTabView

/// 독서 기록 탭 루트 — 스니펫 | 독서일기 | 리뷰 | 독서세션 서브탭.
struct RecordsTabView: View {

    @State private var vm = RecordsViewModel()
    @State private var selectedSubTab: SubTab = .snippet
    @State private var showAddRecord = false

    // 기록 추가 시 책 선택 피커에 쓸 서재 목록
    @State private var libraryBooks: [UserBookDto] = []
    @State private var isLoadingBooks = false
    private let userBookService = UserBookService()

    enum SubTab: Int, CaseIterable {
        case snippet, diary, review, session

        var title: String {
            switch self {
            case .snippet: "스니펫"
            case .diary:   "독서일기"
            case .review:  "리뷰"
            case .session: "독서세션"
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
            VStack(spacing: 0) {
                // 서브탭 세그먼트
                Picker("탭", selection: $selectedSubTab) {
                    ForEach(SubTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // 월 네비게이터 (세션 탭에서는 숨김)
                if selectedSubTab != .session {
                    MonthNavigatorView(year: $vm.selectedYear, month: $vm.selectedMonth)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .onChange(of: vm.selectedYear) { _, _ in
                            Task { await vm.changeMonth(year: vm.selectedYear, month: vm.selectedMonth) }
                        }
                        .onChange(of: vm.selectedMonth) { _, _ in
                            Task { await vm.changeMonth(year: vm.selectedYear, month: vm.selectedMonth) }
                        }
                }

                Divider()

                // 탭별 콘텐츠
                TabView(selection: $selectedSubTab) {
                    RecordListView(vm: vm, type: .snippet)
                        .tag(SubTab.snippet)
                    RecordListView(vm: vm, type: .diary)
                        .tag(SubTab.diary)
                    RecordListView(vm: vm, type: .review)
                        .tag(SubTab.review)
                    SessionsListView(vm: vm)
                        .tag(SubTab.session)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
            }
            .navigationTitle("독서 기록")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // + 버튼: 스니펫/일기/리뷰 탭에서만 노출
                if selectedSubTab != .session {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isLoadingBooks {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button {
                                Task { await openAddRecord() }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
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
