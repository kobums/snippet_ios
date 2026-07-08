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
    @State private var errorMessage: String? = nil
    @State private var showError = false

    // OCR 관련 상태
    @State private var showOCRSourceDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var showOCRResult = false

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

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("\(selectedType.label) 추가")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button {
                                Task { await save() }
                            } label: {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                            .disabled(!isFormValid)
                        }
                    }
                }
                .alert("저장 실패", isPresented: $showError) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "저장 중 오류가 발생했습니다.")
                }
                .fullScreenCover(isPresented: $showCameraPicker) {
                    CameraPicker(image: $capturedImage)
                        .ignoresSafeArea()
                }
                .background {
                    PhotoPicker(image: $capturedImage, isPresented: $showPhotoPicker)
                }
                .onChange(of: capturedImage) { _, newImage in
                    if newImage != nil { showOCRResult = true }
                }
                .sheet(isPresented: $showOCRResult, onDismiss: {
                    capturedImage = nil
                }) {
                    if let image = capturedImage {
                        OCRResultView(image: image) { recognizedText in
                            bodyText = bodyText.isEmpty ? recognizedText : bodyText + "\n" + recognizedText
                        }
                    }
                }
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        Form {
            typeSectionView
            bookSectionView
            contentSectionView
            detailSectionView
        }
    }

    private var typeSectionView: some View {
        Section("기록 유형") {
            Picker("유형", selection: $selectedType) {
                ForEach(RecordType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - 책 선택 섹션

    @ViewBuilder
    private var bookSectionView: some View {
        Section("책") {
            if let lockedBook {
                // 고정된 책 — 읽기 전용 헤더.
                BookHeaderView(
                    title: lockedBook.title,
                    author: lockedBook.author,
                    coverURLString: lockedBook.coverUrl
                )
                .padding(.vertical, 4)
            } else if books.isEmpty {
                // 서재가 비어 있음 — 안내 + 저장 비활성.
                Label("서재에 책을 먼저 추가해주세요", systemImage: "books.vertical")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if books.count == 1, let only = books.first {
                // 책이 하나뿐이면 피커 없이 그대로 표시 (Flutter 패리티).
                bookRow(only)
                    .padding(.vertical, 4)
            } else {
                // 여러 권 — 피커로 선택 (UserBookDto가 Hashable이 아니므로 id로 선택).
                Picker("책 선택", selection: selectedBookIdBinding) {
                    ForEach(books) { book in
                        Text(book.title).tag(book.id)
                    }
                }
                .pickerStyle(.navigationLink)

                if let selectedBook {
                    bookRow(selectedBook)
                        .padding(.vertical, 4)
                }
            }
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

    private var contentSectionView: some View {
        Section {
            ocrButton
            TextEditor(text: $bodyText)
                .frame(minHeight: 150)
        } header: {
            Text("내용 *")
        }
    }

    private var ocrButton: some View {
        Button {
            showOCRSourceDialog = true
        } label: {
            HStack {
                Image(systemName: "camera")
                    .foregroundStyle(Color.accentText)
                Text("카메라로 텍스트 추출")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .confirmationDialog("텍스트 추출 방식 선택", isPresented: $showOCRSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("카메라 촬영") { showCameraPicker = true }
            }
            Button("사진 선택") { showPhotoPicker = true }
            Button("취소", role: .cancel) {}
        }
    }

    private var detailSectionView: some View {
        Section("상세 정보") {
            HStack {
                TextField("태그", text: $tagText)
                    .autocorrectionDisabled()
                Divider()
                TextField("페이지", text: $pageText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
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
            errorMessage = "기록 저장에 실패했습니다. 잠시 후 다시 시도해주세요."
            showError = true
            return
        }
        onSaved?()
        dismiss()
    }
}

#Preview {
    AddRecordView(initialType: .snippet)
}
