import SwiftUI

// MARK: - EditRecordView

/// 기록 수정 화면. AddRecordView 폼을 재사용.
/// AppBar 액션: 취소 / 저장. 삭제는 iOS 관례대로 폼 맨 아래 빨간 행.
/// 변경 사항이 있으면 취소·스와이프 시 폐기 확인 다이얼로그를 띄운다.
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
    @State private var showDeleteConfirm = false
    @State private var showDiscardDialog = false
    @State private var errorTitle = "저장 실패"
    @State private var errorMessage: String? = nil
    @State private var showError = false

    // OCR 관련 상태
    @State private var showOCRSourceDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var showOCRResult = false

    // 메모 이미지 내보내기
    @State private var showNotesExport = false

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

    /// 원본 기록 대비 변경 여부 — 취소/스와이프 시 폐기 확인에 사용.
    private var isDirty: Bool {
        selectedType != record.type
            || bodyText != record.text
            || tagText != (record.tag ?? "")
            || pageText != (record.relatedPage.map { String($0) } ?? "")
    }

    /// 현재 편집 중(미저장 포함) 내용을 반영한 미리보기/공유용 기록.
    private var draftRecord: RecordDto {
        RecordDto(
            id: record.id,
            bookId: record.bookId,
            bookTitle: record.bookTitle,
            bookAuthor: record.bookAuthor,
            bookCoverUrl: record.bookCoverUrl,
            type: selectedType,
            text: bodyText,
            tag: tagText.isEmpty ? nil : tagText,
            relatedPage: Int(pageText),
            createDate: record.createDate
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    bookSectionView
                    contentSectionView
                    detailSectionView
                    exportSectionView
                    deleteSectionView
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            // 키보드는 스크롤 제스처를 따라 인터랙티브하게 내려간다 (AddRecordView와 동일).
            .scrollDismissesKeyboard(.interactively)
            // .background(alignment: .topLeading {
            //     ambientCoverBackground
            //         .ignoresSafeArea(edges: .top)
            // })
            .background(Color(.systemBackground))
            .navigationTitle("기록 수정")
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
                    .disabled(isSaving || isDeleting)
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
                    .disabled(!isFormValid || isSaving || isDeleting)
                }
            }
            // 변경 사항이 있으면 시트 스와이프 닫기를 막고 폐기 확인을 거치게 한다.
            .interactiveDismissDisabled(isDirty)
            .confirmationDialog(
                "변경 사항을 폐기하시겠습니까?",
                isPresented: $showDiscardDialog,
                titleVisibility: .visible
            ) {
                Button("변경 사항 폐기", role: .destructive) { dismiss() }
                Button("계속 편집", role: .cancel) {}
            }
            .alert(errorTitle, isPresented: $showError) {
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
            // 메모 이미지 내보내기 시트
            .sheet(isPresented: $showNotesExport) {
                NotesExportSheet(record: draftRecord)
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

    // MARK: - Form Sections (AddRecordView와 동일한 폼 스타일)

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    /// 책 정보 (읽기 전용) — 책 상세보기의 히어로 헤더와 같은 문법:
    /// 중앙 대형 표지(깊은 그림자) + 세리프 제목 + 저자 + 유형 칩.
    private var bookSectionView: some View {
        VStack(spacing: 0) {
            BookCoverView(
                urlString: record.bookCoverUrl.isEmpty ? nil : record.bookCoverUrl,
                size: .custom(width: 136, height: 198, cornerRadius: AppRadius.cardLarge),
                showsShadow: false
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

            Text(record.bookTitle)
                .font(.serifTitle)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.top, 20)

            if !record.bookAuthor.isEmpty {
                Text(record.bookAuthor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }

            // 유형 셀렉트 — 상세보기의 분류/상태 칩과 같은 문법 (Menu + Picker).
            Menu {
                Picker("기록 유형", selection: Binding(
                    get: { selectedType },
                    set: { newType in
                        Haptics.selection()
                        selectedType = newType
                    }
                )) {
                    ForEach(RecordType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedType.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
    }

    /// 표지 색을 크게 블러해 히어로 뒤에 깔아주는 앰비언트 배경 (책 상세보기와 동일).
    private var ambientCoverBackground: some View {
        AsyncImage(url: record.bookCoverUrl.isEmpty ? nil : URL(string: record.bookCoverUrl)) { phase in
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

    private var contentSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("내용")

            VStack(spacing: 0) {
                ocrButton
                    .padding(12)

                Divider()
                    .padding(.leading, 12)

                TextEditor(text: $bodyText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text(editorPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
        }
    }

    /// 기록 유형에 맞는 플레이스홀더 — 내용을 모두 지웠을 때 무엇을 쓰는 자리인지 알려준다.
    private var editorPlaceholder: String {
        switch selectedType {
        case .snippet: "책 속 인상 깊은 문장을 옮겨 적어보세요"
        case .diary: "오늘의 독서를 기록해보세요"
        case .review: "이 책에 대한 생각을 남겨보세요"
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("상세 정보")

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    TextField("태그", text: $tagText)
                        .autocorrectionDisabled()
                }

                Divider()
                    .frame(height: 20)

                HStack(spacing: 6) {
                    Image(systemName: "book.pages")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    TextField("페이지", text: $pageText)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
        }
    }

    private var exportSectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showNotesExport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.accentText)
                    Text("메모 이미지 내보내기")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentText)
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
            }
            .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("현재 작성 중인 내용을 4:5 이미지 카드로 공유합니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    /// 삭제 — 파괴적 액션은 확정 버튼(저장) 옆이 아닌 폼 맨 아래 빨간 행 (iOS 관례).
    private var deleteSectionView: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Spacer()
                if isDeleting {
                    ProgressView()
                } else {
                    Text("기록 삭제")
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
            }
            .padding(.vertical, 13)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppRadius.cardLarge))
        }
        .disabled(isSaving || isDeleting)
        .confirmationDialog(
            "이 기록을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("기록 삭제", role: .destructive) {
                Task { await deleteRecord() }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func save() async {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorTitle = "저장 실패"
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
            Haptics.success()
            onDismiss?()
            dismiss()
        } else {
            Haptics.error()
            errorTitle = "저장 실패"
            errorMessage = "저장 중 오류가 발생했습니다."
            showError = true
        }
    }

    private func deleteRecord() async {
        isDeleting = true
        defer { isDeleting = false }

        let success = await vm.deleteRecord(id: record.id)
        if success {
            Haptics.success()
            onDismiss?()
            dismiss()
        } else {
            Haptics.error()
            errorTitle = "삭제 실패"
            errorMessage = "삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            showError = true
        }
    }
}
