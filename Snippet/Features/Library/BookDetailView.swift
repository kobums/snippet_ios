import SwiftUI

// MARK: - BookDetailView

/// 책 상세 화면.
/// 단일 스크롤 구조: 헤더(분류/상태 칩) → 정보 카드 → 기록 섹션 → 독서세션 섹션.
/// 기록/세션은 최근 3개만 보여주고 "전체 보기"로 리스트 화면에 진입한다.
struct BookDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let userBook: UserBookDto
    @Bindable var viewModel: LibraryViewModel

    @State private var localBook: UserBookDto
    @State private var showDeleteAlert = false
    @State private var showDeleteError = false
    @State private var showRatingSheet = false
    @State private var isSaving = false
    @State private var readPageText = ""
    @State private var showReturnDatePicker = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var tempReturnDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var tempStartDate: Date = Date()
    @State private var tempEndDate: Date = Date()
    @State private var showReadingTimer = false
    @State private var showAddRecord = false

    init(userBook: UserBookDto, viewModel: LibraryViewModel) {
        self.userBook = userBook
        self.viewModel = viewModel
        _localBook = State(initialValue: userBook)
        _readPageText = State(initialValue: String(userBook.readPage))
    }

    /// 섹션 미리보기에 노출할 최대 개수.
    private static let previewCount = 3

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                    .padding(.horizontal)
                    .padding(.top, 12)

                // 주 행동 CTA — 히어로 바로 아래, 대상(책)과 가까이.
                if localBook.status == .reading {
                    startReadingButton
                        .padding(.horizontal)
                        .padding(.top, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                // 정보 카드 — 분류/상태 변경으로 카드가 나타나고 사라질 때 스프링으로 재배치.
                VStack(spacing: 12) {
                    if localBook.type != .wish {
                        progressCard
                    }

                    detailsCard
                }
                .padding(.horizontal)
                .padding(.top, 24)

                recordsSummarySection
                    .padding(.top, 32)

                sessionsSummarySection
                    .padding(.top, 32)

                Spacer(minLength: 32)
            }
            .animation(.smooth(duration: 0.35), value: localBook.status)
            .animation(.smooth(duration: 0.35), value: localBook.type)
        }
        .background(alignment: .top) {
            ambientCoverBackground
                .ignoresSafeArea(edges: .top)
        }
        .navigationTitle(localBook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showAddRecord = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            // 파괴적 액션은 자주 쓰는 + 버튼 옆에 직접 노출하지 않고 더보기 메뉴 안에 둔다.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Haptics.warning()
                        showDeleteAlert = true
                    } label: {
                        Label("서재에서 삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddRecord, onDismiss: {
            Task { await viewModel.loadBookRecords(bookId: localBook.bookId) }
        }) {
            AddRecordView(
                initialType: .snippet,
                lockedBook: localBook,
                onSaved: { showAddRecord = false }
            )
        }
        .alert("책 삭제", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                Task {
                    if await viewModel.deleteBook(id: localBook.id) {
                        Haptics.success()
                        dismiss()
                    } else {
                        Haptics.error()
                        showDeleteError = true
                    }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("'\(localBook.title)'을(를) 서재에서 삭제하시겠습니까?")
        }
        .alert("삭제 실패", isPresented: $showDeleteError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.")
        }
        .sheet(isPresented: $showRatingSheet) {
            RatingSheet(
                bookTitle: localBook.title,
                currentRating: localBook.rating ?? 0,
                onSave: { rating in
                    Task { await saveUpdate(.init(rating: rating)) }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStartDatePicker) {
            DatePickerSheet(title: "시작 날짜", date: $tempStartDate) {
                Task { await saveUpdate(.init(startDate: APIDate.dayString(from: tempStartDate))) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEndDatePicker) {
            DatePickerSheet(title: "완료 날짜", date: $tempEndDate) {
                Task { await saveUpdate(.init(endDate: APIDate.dayString(from: tempEndDate))) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReturnDatePicker) {
            DatePickerSheet(title: "반납 예정일", date: $tempReturnDate) {
                Task { await saveUpdate(.init(returnDate: APIDate.dayString(from: tempReturnDate))) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.loadBookRecords(bookId: localBook.bookId)
            await viewModel.loadBookSessions(userBookId: localBook.id)
        }
        .fullScreenCover(isPresented: $showReadingTimer) {
            ReadingTimerView(
                userBookId: localBook.id,
                startPage: localBook.readPage,
                bookTitle: localBook.title,
                onDismiss: {
                    showReadingTimer = false
                    Task {
                        await viewModel.loadBookSessions(userBookId: localBook.id)
                    }
                }
            )
        }
    }

    // MARK: - 히어로 헤더

    /// 중앙 대형 표지 + 세리프 제목 + 저자 + 분류/상태 칩.
    /// 큰 표면일수록 깊은 그림자 — 표지가 화면 위에 떠 있는 물성을 만든다.
    private var heroHeader: some View {
        VStack(spacing: 0) {
            BookCoverView(
                urlString: localBook.coverUrl,
                size: .custom(width: 136, height: 198, cornerRadius: AppRadius.cardLarge),
                showsShadow: false
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

            Text(localBook.title)
                .font(.serifTitle)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.top, 20)

            if !localBook.author.isEmpty {
                Text(localBook.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }

            attributeChips
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
    }

    /// 표지 색을 크게 블러해 히어로 뒤에 깔아주는 앰비언트 배경.
    /// 아래로 갈수록 사라져 콘텐츠와 자연스럽게 이어진다(스크롤 엣지 효과).
    private var ambientCoverBackground: some View {
        AsyncImage(url: localBook.coverUrl.isEmpty ? nil : URL(string: localBook.coverUrl)) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipped()
        .blur(radius: 60)
        .opacity(0.35)
        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }

    // MARK: - 주 행동 CTA

    /// 독서 시작 — 읽는 중 상태에서만 노출되는 화면의 주 행동.
    private var startReadingButton: some View {
        Button {
            Haptics.medium()
            showReadingTimer = true
        } label: {
            Label("독서 시작", systemImage: "play.fill")
                .font(.headline)
                // 다크 모드에서 accent(흰색) 캡슐 위 라벨이 흰색으로 렌더링되지 않도록 onAccent 강제.
                .foregroundStyle(Color.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
    }

    // MARK: - 분류/상태 칩

    // 칩은 히어로 중앙 — 조작 대상(책) 바로 아래에 붙어 관계를 드러낸다.
    private var attributeChips: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("분류", selection: Binding(
                    get: { localBook.type },
                    set: { newType in
                        Haptics.selection()
                        Task { await saveUpdate(.init(type: newType)) }
                    }
                )) {
                    Text("위시리스트").tag(BookType.wish)
                    Text("소장").tag(BookType.have)
                    Text("대출").tag(BookType.borrow)
                    if localBook.type == .returned {
                        Text("반납").tag(BookType.returned)
                    }
                }
            } label: {
                chipLabel(typeLabel(localBook.type))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)

            if localBook.type != .wish {
                Menu {
                    Picker("상태", selection: Binding(
                        get: { localBook.status },
                        set: { newStatus in
                            Haptics.selection()
                            Task { await saveUpdate(.init(status: newStatus)) }
                        }
                    )) {
                        Text("읽을 예정").tag(BookStatus.waiting)
                        Text("읽는 중").tag(BookStatus.reading)
                        Text("완독").tag(BookStatus.completed)
                        Text("중단").tag(BookStatus.dropped)
                    }
                } label: {
                    chipLabel(statusLabel(localBook.status))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
    }

    private func chipLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 정보 카드

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("진행률")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if localBook.totalPage > 0 {
                    Text("\(Int(localBook.progress * 100))%")
                        .font(.statValueSmall)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: localBook.progress))
                }
            }

            if localBook.totalPage > 0 {
                ProgressView(value: localBook.progress)
                    .tint(.accentColor)
            }

            HStack(spacing: 8) {
                TextField("페이지", text: $readPageText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .onSubmit { commitReadPage() }

                if localBook.totalPage > 0 {
                    Text("/ \(localBook.totalPage) 페이지")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 저장 중에는 스피너로 진행 상태를 노출 — 상태 피드백.
                Button {
                    commitReadPage()
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentText)
                    }
                }
                .disabled(isSaving)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
        // 진행률 변경은 현재 값에서 목표 값으로 스프링 전환 (바 + 퍼센트 동시).
        .animation(.smooth(duration: 0.5), value: localBook.progress)
    }

    /// 읽은 페이지 커밋. 버튼 탭과 키보드 완료가 같은 경로를 탄다.
    /// 마지막 페이지 도달 시 완독 처리 + 성공 햅틱 + 별점 시트.
    private func commitReadPage() {
        let page = Int(readPageText) ?? 0
        Task {
            var req = UserBookUpdateRequest(readPage: page)
            let isCompleting = page == localBook.totalPage && localBook.totalPage > 0
            if isCompleting {
                req.status = .completed
                if localBook.endDate == nil {
                    req.endDate = APIDate.dayString()
                }
            }
            await saveUpdate(req)
            if isCompleting {
                Haptics.success()
                showRatingSheet = true
            } else {
                Haptics.light()
            }
        }
    }

    /// 시작일·완료일·반납·별점을 한 카드에 행으로 묶은 상세 정보(설정 앱식 그룹 리스트).
    /// 흩어져 있던 세 카드를 하나로 — 같은 성격의 정보는 한 그룹에 (proximity = relationship).
    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "시작일", value: localBook.startDate.map { String($0.prefix(10)) }) {
                if let startDateStr = localBook.startDate {
                    tempStartDate = APIDate.parseDay(String(startDateStr.prefix(10))) ?? Date()
                }
                showStartDatePicker = true
            }

            if localBook.status == .completed {
                rowDivider
                detailRow(label: "완료일", value: localBook.endDate.map { String($0.prefix(10)) }) {
                    if let endDateStr = localBook.endDate {
                        tempEndDate = APIDate.parseDay(String(endDateStr.prefix(10))) ?? Date()
                    }
                    showEndDatePicker = true
                }
            }

            if localBook.type == .borrow {
                rowDivider
                detailRow(
                    label: "반납 예정일",
                    value: localBook.returnDate.map { String($0.prefix(10)) },
                    badge: ddayBadge
                ) {
                    if let returnDateStr = localBook.returnDate {
                        tempReturnDate = APIDate.parseDay(String(returnDateStr.prefix(10))) ?? Date().addingTimeInterval(60 * 60 * 24 * 14)
                    }
                    showReturnDatePicker = true
                }
            }

            if localBook.status == .completed {
                rowDivider
                ratingRow
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 16)
    }

    private func detailRow(
        label: String,
        value: String?,
        badge: (text: String, color: Color)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let badge {
                    Text(badge.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge.color, in: Capsule())
                }

                Spacer()

                Text(value ?? "미설정")
                    .font(.subheadline)
                    .foregroundStyle(value != nil ? .primary : .tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var ratingRow: some View {
        Button {
            showRatingSheet = true
        } label: {
            HStack(spacing: 8) {
                Text("별점")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let rating = localBook.rating, rating > 0 {
                    RatingStarsView(rating: rating, starSize: 14, spacing: 2)
                } else {
                    Text("평가하기")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var ddayBadge: (text: String, color: Color)? {
        guard let returnDateStr = localBook.returnDate else { return nil }
        guard let returnDate = APIDate.parseDay(String(returnDateStr.prefix(10))) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: returnDate)
        let diff = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        if diff < 0 {
            return ("연체 \(-diff)일", Color(.systemRed))
        } else if diff == 0 {
            return ("오늘 반납", Color(.systemOrange))
        } else if diff <= 3 {
            return ("D-\(diff)", Color(.systemOrange))
        } else {
            return ("D-\(diff)", Color(.systemGreen))
        }
    }

    // MARK: - 기록 섹션

    private var recordsSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "기록",
                count: viewModel.bookRecords.count,
                destination: BookRecordsListView(viewModel: viewModel, book: localBook)
            )

            if viewModel.isLoadingBookRecords {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.bookRecords.isEmpty {
                emptySectionCard(
                    systemImage: "square.and.pencil",
                    text: "아직 기록이 없습니다. 상단 +로 추가해보세요."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.bookRecords.prefix(Self.previewCount)) { record in
                        BookDetailRecordCard(record: record)
                    }
                }
                .padding(.horizontal)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.isLoadingBookRecords)
    }

    // MARK: - 세션 섹션

    private var sessionsSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "독서 세션",
                count: viewModel.bookSessions.count,
                destination: BookSessionsListView(viewModel: viewModel)
            )

            if viewModel.isLoadingBookSessions {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.bookSessions.isEmpty {
                emptySectionCard(
                    systemImage: "timer",
                    text: "아직 독서 세션이 없습니다. 독서를 시작해보세요."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.bookSessions.prefix(Self.previewCount)) { session in
                        BookDetailSessionCard(session: session)
                    }
                }
                .padding(.horizontal)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.isLoadingBookSessions)
    }

    // MARK: - 섹션 공통

    private func sectionHeader(title: String, count: Int, destination: some View) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            if count > 0 {
                Text("\(count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if count > Self.previewCount {
                NavigationLink {
                    destination
                } label: {
                    HStack(spacing: 2) {
                        Text("전체 보기")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private func emptySectionCard(systemImage: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - 헬퍼

    private func typeLabel(_ type: BookType) -> String {
        switch type {
        case .wish: return "위시리스트"
        case .have: return "소장"
        case .borrow: return "대출"
        case .returned: return "반납"
        }
    }

    private func statusLabel(_ status: BookStatus) -> String {
        switch status {
        case .waiting: return "읽을 예정"
        case .reading: return "읽는 중"
        case .completed: return "완독"
        case .dropped: return "중단"
        case .none: return ""
        }
    }

    private func saveUpdate(_ request: UserBookUpdateRequest) async {
        isSaving = true
        defer { isSaving = false }
        let result = try? await UserBookService().update(id: localBook.id, request)
        if let updated = result {
            localBook = updated
            readPageText = String(updated.readPage)
        }
        await viewModel.loadAllTabs()
    }
}

// MARK: - BookRecordsListView

/// 책의 전체 기록 리스트. 타입(스니펫/독서일기/리뷰) 칩 필터 제공.
private struct BookRecordsListView: View {
    @Bindable var viewModel: LibraryViewModel
    let book: UserBookDto

    @State private var selectedType: RecordType = .snippet
    @State private var showAddRecord = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 기록 타입 칩 선택
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RecordType.allCases, id: \.self) { type in
                            Button {
                                Haptics.selection()
                                selectedType = type
                            } label: {
                                Text(type.label)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedType == type ? Color.accentColor : Color(.secondarySystemBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(selectedType == type ? Color.onAccent : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                let filteredRecords = viewModel.bookRecords.filter { $0.type == selectedType }
                if filteredRecords.isEmpty {
                    EmptyStateView(
                        systemImage: "square.and.pencil",
                        title: "아직 \(selectedType.label)이(가) 없습니다",
                        message: nil
                    )
                    .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRecords) { record in
                            BookDetailRecordCard(record: record)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer(minLength: 32)
            }
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showAddRecord = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRecord, onDismiss: {
            Task { await viewModel.loadBookRecords(bookId: book.bookId) }
        }) {
            AddRecordView(
                initialType: selectedType,
                lockedBook: book,
                onSaved: { showAddRecord = false }
            )
        }
    }
}

// MARK: - BookSessionsListView

/// 책의 전체 독서 세션 리스트.
private struct BookSessionsListView: View {
    @Bindable var viewModel: LibraryViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.bookSessions) { session in
                    BookDetailSessionCard(session: session)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)

            Spacer(minLength: 32)
        }
        .navigationTitle("독서 세션")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - BookDetailRecordCard

private struct BookDetailRecordCard: View {
    let record: RecordDto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.type.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let tag = record.tag, !tag.isEmpty {
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                }
                Spacer()
                HStack(spacing: 6) {
                    if let page = record.relatedPage {
                        Text("p.\(page)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(String(record.createDate.prefix(10)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(record.text)
                .font(.subheadline)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - BookDetailSessionCard

private struct BookDetailSessionCard: View {
    let session: ReadingSessionDto

    var durationText: String {
        let h = session.durationSeconds / 3600
        let m = (session.durationSeconds % 3600) / 60
        if h > 0 { return "\(h)시간 \(m)분" }
        return "\(m)분"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.sessionDate)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(durationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("\(session.startPage)p → \(session.endPage)p")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("+\(session.pagesRead)p")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.systemGreen))
                Spacer()
                let pace = session.secondsPerPage > 0 ? session.secondsPerPage / 60.0 : 0
                Text("페이스: \(String(format: "%.1f", pace)) min/p")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - DatePickerSheet

private struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                title,
                selection: $date,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("선택") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - RatingSheet

private struct RatingSheet: View {
    let bookTitle: String
    let currentRating: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int

    private let labels = ["", "별로였어요", "그저 그랬어요", "괜찮았어요", "좋았어요!", "최고였어요!"]

    init(bookTitle: String, currentRating: Int, onSave: @escaping (Int) -> Void) {
        self.bookTitle = bookTitle
        self.currentRating = currentRating
        self.onSave = onSave
        _rating = State(initialValue: currentRating)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentText)

                Text("독서 완료!")
                    .font(.title2.weight(.bold))

                Text(bookTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("이 책은 어떠셨나요?")
                    .font(.body)

                RatingStarsView(rating: rating, starSize: 44) { newRating in
                    rating = newRating
                }

                if rating > 0 {
                    Text(labels[rating])
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .animation(.smooth(duration: 0.25), value: rating)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("별점")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("건너뛰기") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        onSave(rating)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(rating == 0)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(
            userBook: UserBookDto(
                id: 1, bookId: 1, title: "데미안", author: "헤르만 헤세",
                coverUrl: "", type: .have, status: .reading,
                readPage: 120, totalPage: 248,
                createDate: "2024-01-01", startDate: "2024-01-01",
                endDate: nil, rating: nil, returnDate: nil
            ),
            viewModel: LibraryViewModel()
        )
    }
}

// MARK: - UserBookDto convenience init for preview

extension UserBookDto {
    init(
        id: Int, bookId: Int, title: String, author: String,
        coverUrl: String, type: BookType, status: BookStatus,
        readPage: Int, totalPage: Int, createDate: String,
        startDate: String?, endDate: String?, rating: Int?, returnDate: String?
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.type = type
        self.status = status
        self.readPage = readPage
        self.totalPage = totalPage
        self.createDate = createDate
        self.startDate = startDate
        self.endDate = endDate
        self.rating = rating
        self.returnDate = returnDate
    }
}
