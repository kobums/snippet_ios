import SwiftUI

// MARK: - AddRecordView

/// 기록 작성 화면 — 타입 선택, 서재 책 선택(또는 고정), 본문, 태그, 페이지.
/// 기록은 반드시 서재의 실제 책(`bookId`)에 연결된다.
/// - `books`: 책 선택 피커에 사용할 서재 후보 목록.
/// - `lockedBook`: 책 상세에서 진입한 경우처럼 책이 고정된 경우 — 피커 없이 읽기 전용으로 표시.
/// 내용 섹션의 카메라 버튼을 탭하면 카메라 촬영/사진 선택 메뉴가 표시되고,
/// 선택한 이미지를 Vision OCR로 인식한 후 결과 텍스트를 본문에 삽입한다.
struct AddRecordView: View {

    let initialType: RecordType
    var initialText: String = ""
    /// 책 선택 피커 후보 (lockedBook이 nil일 때 사용).
    var books: [UserBookDto] = []
    /// 고정된 책 (책 상세에서 진입 시). non-nil이면 피커 대신 읽기 전용 헤더 표시.
    var lockedBook: UserBookDto? = nil
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    private let service = RecordService()

    // 폼 필드
    @State private var selectedType: RecordType
    @State private var selectedBook: UserBookDto?
    @State private var bodyText: String = ""
    @State private var tagText: String = ""
    @State private var pageText: String = ""

    @State private var isSaving = false
    @State private var showDiscardDialog = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    // OCR 관련 상태 — 나머지 파이프라인 상태는 ocrCaptureFlow가 소유.
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false

    init(
        initialType: RecordType,
        initialText: String = "",
        books: [UserBookDto] = [],
        lockedBook: UserBookDto? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.initialType = initialType
        self.initialText = initialText
        self.books = books
        self.lockedBook = lockedBook
        self.onSaved = onSaved
        _selectedType = State(initialValue: initialType)
        _bodyText = State(initialValue: initialText)
        // 고정 책이 있으면 그것을, 없으면 후보 첫 책을 기본 선택.
        _selectedBook = State(initialValue: lockedBook ?? books.first)
    }

    /// 선택 가능한 책이 하나도 없는 상태 (서재가 비어 있음).
    private var hasNoBooks: Bool {
        lockedBook == nil && books.isEmpty
    }

    private var isFormValid: Bool {
        guard !hasNoBooks, selectedBook != nil else { return false }
        return !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 진입 시점 대비 입력 변경 여부 — 취소/스와이프 시 폐기 확인에 사용.
    private var isDirty: Bool {
        bodyText != initialText || !tagText.isEmpty || !pageText.isEmpty
    }

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("\(selectedType.label) 추가")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            if isDirty {
                                showDiscardDialog = true
                            } else {
                                dismiss()
                            }
                        }
                        .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("저장")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(!isFormValid || isSaving)
                    }
                }
                // 작성 중인 내용이 있으면 시트 스와이프 닫기를 막고 폐기 확인을 거치게 한다.
                .interactiveDismissDisabled(isDirty)
                .confirmationDialog(
                    "작성 중인 내용을 폐기하시겠습니까?",
                    isPresented: $showDiscardDialog,
                    titleVisibility: .visible
                ) {
                    Button("내용 폐기", role: .destructive) { dismiss() }
                    Button("계속 작성", role: .cancel) {}
                }
                .alert("저장 실패", isPresented: $showError) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "저장 중 오류가 발생했습니다.")
                }
                .ocrCaptureFlow(
                    showCameraPicker: $showCameraPicker,
                    showPhotoPicker: $showPhotoPicker,
                    bodyText: $bodyText
                )
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                typeSectionView
                bookSectionView
                RecordContentSection(
                    bodyText: $bodyText,
                    placeholder: selectedType.editorPlaceholder,
                    showCameraPicker: $showCameraPicker,
                    showPhotoPicker: $showPhotoPicker
                )
                RecordDetailFieldsSection(tagText: $tagText, pageText: $pageText)
            }
            .padding(16)
        }
        // 키보드는 스크롤 제스처를 따라 인터랙티브하게 내려간다 (1:1 추적).
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
    }

    private var typeSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "기록 유형")
            GlassSegmentedControl(
                segments: RecordType.allCases.map { ($0, $0.label) },
                selection: $selectedType
            )
        }
    }

    // MARK: - 책 선택 섹션

    @ViewBuilder
    private var bookSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "책")

            Group {
                if let lockedBook {
                    // 고정된 책 — 읽기 전용 헤더.
                    BookHeaderView(
                        title: lockedBook.title,
                        author: lockedBook.author,
                        coverURLString: lockedBook.coverUrl
                    )
                } else if books.isEmpty {
                    // 서재가 비어 있음 — 안내 + 저장 비활성.
                    Label("서재에 책을 먼저 추가해주세요", systemImage: "books.vertical")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if books.count == 1, let only = books.first {
                    // 책이 하나뿐이면 피커 없이 그대로 표시 (Flutter 패리티).
                    bookRow(only)
                } else if let selectedBook {
                    // 여러 권 — 선택된 책 행 자체가 메뉴 트리거 (조작 대상 = 컨트롤).
                    Menu {
                        Picker("책 선택", selection: selectedBookIdBinding) {
                            ForEach(books) { book in
                                Text(book.title).tag(book.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            bookRow(selectedBook)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
        }
    }

    /// 피커용 id 바인딩 — 선택한 책 id로 selectedBook을 갱신한다.
    private var selectedBookIdBinding: Binding<Int> {
        Binding(
            get: { selectedBook?.id ?? books.first?.id ?? -1 },
            set: { newId in selectedBook = books.first { $0.id == newId } }
        )
    }

    private func bookRow(_ book: UserBookDto) -> some View {
        HStack(spacing: 12) {
            BookCoverView(urlString: book.coverUrl, size: .small)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func save() async {
        guard let book = selectedBook else {
            errorMessage = "책을 선택해주세요."
            showError = true
            return
        }
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "내용을 입력해주세요."
            showError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        // 선택한 서재 책의 bookId로 기록을 연결한다.
        let request = RecordAddRequest(
            bookId: book.bookId,
            type: selectedType,
            text: trimmed,
            tag: tagText.isEmpty ? nil : tagText,
            relatedPage: Int(pageText)
        )

        do {
            _ = try await service.add(request)
        } catch {
            // 저장 실패 시 화면을 닫지 않고 오류를 노출해 기록 유실을 방지한다.
            Haptics.error()
            errorMessage = "기록 저장에 실패했습니다. 잠시 후 다시 시도해주세요."
            showError = true
            return
        }
        Haptics.success()
        onSaved?()
        dismiss()
    }
}

#Preview {
    AddRecordView(initialType: .snippet)
}
