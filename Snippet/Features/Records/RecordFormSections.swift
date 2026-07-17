import SwiftUI
import UIKit

// MARK: - 기록 폼 공용 어휘
// AddRecordView / EditRecordView가 공유하는 섹션·OCR 파이프라인.
// 폼 스타일을 바꿀 때 두 화면이 함께 따라오도록 여기에서만 정의한다.

extension RecordType {
    /// 기록 유형에 맞는 에디터 플레이스홀더 — 무엇을 쓰는 자리인지 구체적으로 말해준다.
    var editorPlaceholder: String {
        switch self {
        case .snippet: "책 속 인상 깊은 문장을 옮겨 적어보세요"
        case .diary: "오늘의 독서를 기록해보세요"
        case .review: "이 책에 대한 생각을 남겨보세요"
        }
    }
}

/// 내용 섹션 — OCR 진입 버튼 + 플레이스홀더 딸린 TextEditor 카드.
/// OCR 방식 선택 다이얼로그는 내부에서 소유하고, 선택 결과만 카메라/사진 바인딩으로 알린다.
struct RecordContentSection: View {

    @Binding var bodyText: String
    let placeholder: String
    @Binding var showCameraPicker: Bool
    @Binding var showPhotoPicker: Bool

    @State private var showOCRSourceDialog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "내용")

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
                            Text(placeholder)
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
}

/// 상세 정보 섹션 — 태그·페이지 입력 카드.
struct RecordDetailFieldsSection: View {

    @Binding var tagText: String
    @Binding var pageText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "상세 정보")

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
}

extension View {
    /// 카메라 촬영/사진 선택 → OCR 인식 → 확정 텍스트를 본문에 삽입하는 공용 파이프라인.
    /// 촬영 이미지·결과 시트 상태는 내부에서 소유한다.
    func ocrCaptureFlow(
        showCameraPicker: Binding<Bool>,
        showPhotoPicker: Binding<Bool>,
        bodyText: Binding<String>
    ) -> some View {
        modifier(OCRCaptureFlow(
            showCameraPicker: showCameraPicker,
            showPhotoPicker: showPhotoPicker,
            bodyText: bodyText
        ))
    }
}

private struct OCRCaptureFlow: ViewModifier {

    @Binding var showCameraPicker: Bool
    @Binding var showPhotoPicker: Bool
    @Binding var bodyText: String

    @State private var capturedImage: UIImage? = nil
    @State private var showOCRResult = false

    func body(content: Content) -> some View {
        content
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
                if newImage != nil { showOCRResult = true }
            }
            // OCR 결과 편집 화면 — 확정 텍스트를 본문에 삽입 (기존 내용이 있으면 줄바꿈 후 추가)
            .sheet(isPresented: $showOCRResult, onDismiss: { capturedImage = nil }) {
                if let image = capturedImage {
                    OCRResultView(image: image) { recognizedText in
                        bodyText = bodyText.isEmpty ? recognizedText : bodyText + "\n" + recognizedText
                    }
                }
            }
    }
}
