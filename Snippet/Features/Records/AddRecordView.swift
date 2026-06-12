import SwiftUI

// MARK: - AddRecordView

/// 기록 작성 화면 — 타입 선택, 책 제목/저자 입력, 본문, 태그, 페이지, 리뷰 별점.
/// 내용 섹션의 카메라 버튼을 탭하면 카메라 촬영/사진 선택 메뉴가 표시되고,
/// 선택한 이미지를 Vision OCR로 인식한 후 결과 텍스트를 본문에 삽입한다.
struct AddRecordView: View {

    let initialType: RecordType
    var initialText: String = ""
    var bookId: Int? = nil
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    private let service = RecordService()

    // 폼 필드
    @State private var selectedType: RecordType
    @State private var bookTitle: String = ""
    @State private var bookAuthor: String = ""
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

    init(initialType: RecordType, initialText: String = "", bookId: Int? = nil, onSaved: (() -> Void)? = nil) {
        self.initialType = initialType
        self.initialText = initialText
        self.bookId = bookId
        self.onSaved = onSaved
        _selectedType = State(initialValue: initialType)
        _bodyText = State(initialValue: initialText)
    }

    private var isFormValid: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            bookInfoSectionView
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

    private var bookInfoSectionView: some View {
        Section("책 정보") {
            TextField("책 제목 *", text: $bookTitle)
                .autocorrectionDisabled()
            TextField("저자", text: $bookAuthor)
                .autocorrectionDisabled()
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
                    .foregroundStyle(Color.accentColor)
                Text("카메라로 텍스트 추출")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
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
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "내용을 입력해주세요."
            showError = true
            return
        }
        guard !bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "책 제목을 입력해주세요."
            showError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        // bookId가 없을 때는 임시로 0 전송 (서버 측에서 처리)
        // 실제 플로우에서는 책 상세에서 bookId를 전달받아야 함
        let request = RecordAddRequest(
            bookId: bookId ?? 0,
            type: selectedType,
            text: trimmed,
            tag: tagText.isEmpty ? nil : tagText,
            relatedPage: Int(pageText)
        )

        let _ = try? await service.add(request)
        onSaved?()
        dismiss()
    }
}

#Preview {
    AddRecordView(initialType: .snippet)
}
