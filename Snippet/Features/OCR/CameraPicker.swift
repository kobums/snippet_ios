import SwiftUI
import UIKit

// MARK: - CameraPicker

/// UIImagePickerController(.camera)를 SwiftUI에서 사용하기 위한 UIViewControllerRepresentable 래퍼.
///
/// 시뮬레이터에서는 카메라를 사용할 수 없어 `UIImagePickerController.isSourceTypeAvailable(.camera)`가
/// false를 반환하므로 실제 기기에서만 동작한다. 빌드는 시뮬레이터에서도 통과한다.
///
/// 사용 예:
/// ```swift
/// @State private var showCamera = false
/// @State private var capturedImage: UIImage? = nil
///
/// .sheet(isPresented: $showCamera) {
///     CameraPicker(image: $capturedImage)
/// }
/// ```
struct CameraPicker: UIViewControllerRepresentable {

    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
