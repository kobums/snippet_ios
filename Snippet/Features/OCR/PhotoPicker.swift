import SwiftUI
import PhotosUI

// MARK: - PhotoPickerModifier

/// PhotosUI의 PhotosPicker를 `.photosPicker(isPresented:selection:)` 모디파이어로 표시하는 View.
///
/// 시스템 PhotosPicker는 별도의 권한 요청 없이 동작하며(iOS 16+ 기본),
/// 시뮬레이터에서도 정상적으로 동작한다.
///
/// AddRecordView / EditRecordView에서 `.background { PhotoPicker(...) }` 형태로 사용:
/// ```swift
/// .background {
///     PhotoPicker(image: $selectedImage, isPresented: $showPhotoPicker)
/// }
/// ```
struct PhotoPicker: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        EmptyView()
            .photosPicker(
                isPresented: $isPresented,
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            image = uiImage
                        }
                    }
                    await MainActor.run {
                        selectedItem = nil
                    }
                }
            }
    }
}
