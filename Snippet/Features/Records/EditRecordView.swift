import SwiftUI

// MARK: - EditRecordView

/// 기록 수정 화면. AddRecordView 폼을 재사용.
/// AppBar 액션: 삭제(빨강 휴지통, 확인 다이얼로그) / 저장(체크).
/// 내용 섹션의 카메라 버튼으로 OCR 텍스트를 본문에 추가할 수 있다.
struct EditRecordView: View {

    let record: RecordDto
    @Bindable var vm: RecordsViewModel
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: RecordType
    @State private var bodyText: String
    @State private var tagText: String
    @State private var pageText: String

    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    // OCR 관련 상태
    @State private var showOCRSourceDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var showOCRResult = false

    init(record: RecordDto, vm: RecordsViewModel, onDismiss: (() -> Void)? = nil) {
        self.record = record
        self.vm = vm
        self.onDismiss = onDismiss
        _selectedType = State(initialValue: record.type)
        _bodyText = State(initialValue: record.text)
        _tagText = State(initialValue: record.tag ?? "")
        _pageText = State(initialValue: record.relatedPage.map { String($0) } ?? "")
    }

    private var isFormValid: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // 책 정보 (읽기 전용)
                Section("책 정보") {
                    BookHeaderView(
                        title: record.bookTitle,
                        author: record.bookAuthor.isEmpty ? nil : record.bookAuthor,
                        coverURLString: record.bookCoverUrl.isEmpty ? nil : record.bookCoverUrl,
                        badge: record.type.label
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                // 타입 선택
                Section("기록 유형") {
                    Picker("유형", selection: $selectedType) {
                        ForEach(RecordType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // 내용
                Section {
                    // OCR 버튼 — 카메라 촬영 또는 사진 선택
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
                            Button("카메라 촬영") {
                                showCameraPicker = true
                            }
                        }
                        Button("사진 선택") {
                            showPhotoPicker = true
                        }
                        Button("취소", role: .cancel) {}
                    }

                    TextEditor(text: $bodyText)
                        .frame(minHeight: 150)
                } header: {
                    Text("내용 *")
                }

                // 태그 & 페이지
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
            .navigationTitle("기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 삭제 버튼
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(isSaving || isDeleting)

                    // 저장 버튼
                    if isSaving || isDeleting {
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
            .alert("이 기록을 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) {
                    Task { await deleteRecord() }
                }
                Button("취소", role: .cancel) {}
            }
            .alert("저장 실패", isPresented: $showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "저장 중 오류가 발생했습니다.")
            }
            // 카메라 촬영 sheet
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPicker(image: $capturedImage)
                    .ignoresSafeArea()
            }
            // 사진 선택 (PhotosPicker — 시뮬레이터 지원)
            .background {
                PhotoPicker(image: $capturedImage, isPresented: $showPhotoPicker)
            }
            // 이미지 선택 완료 → OCR 결과 화면 표시
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    showOCRResult = true
                }
            }
            // OCR 결과 편집 화면
            .sheet(isPresented: $showOCRResult, onDismiss: {
                capturedImage = nil
            }) {
                if let image = capturedImage {
                    OCRResultView(image: image) { recognizedText in
                        // 확정된 텍스트를 본문에 삽입 (기존 내용이 있으면 줄바꿈 후 추가)
                        if bodyText.isEmpty {
                            bodyText = recognizedText
                        } else {
                            bodyText += "\n" + recognizedText
                        }
                    }
                }
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

        isSaving = true
        defer { isSaving = false }

        let request = RecordUpdateRequest(
            type: selectedType,
            text: trimmed,
            tag: tagText.isEmpty ? nil : tagText,
            relatedPage: Int(pageText)
        )

        let success = await vm.updateRecord(id: record.id, request)
        if success {
            onDismiss?()
            dismiss()
        } else {
            errorMessage = "저장 중 오류가 발생했습니다."
            showError = true
        }
    }

    private func deleteRecord() async {
        isDeleting = true
        defer { isDeleting = false }

        await vm.deleteRecord(id: record.id)
        onDismiss?()
        dismiss()
    }
}
