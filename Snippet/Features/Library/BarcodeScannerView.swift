import SwiftUI
import VisionKit

// MARK: - BarcodeScannerView

/// ISBN 바코드 스캔 시트.
/// VisionKit `DataScannerViewController`로 EAN-13/EAN-8 바코드를 인식해 숫자 코드를 콜백한다.
/// 별도 SDK 없이 기본 프레임워크만 사용한다(앱 타깃 iOS 26+).
struct BarcodeScannerView: View {

    /// 인식된 숫자 코드(payload) 전달. 호출 측에서 시트를 닫고 검색에 사용한다.
    let onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ZStack(alignment: .bottom) {
                        DataScannerRepresentable(onScanned: handleScan)
                            .ignoresSafeArea(edges: .bottom)

                        Text("책 뒤표지의 바코드를 비춰주세요")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: Capsule())
                            .padding(.bottom, 32)
                    }
                } else {
                    unavailableState
                }
            }
            .navigationTitle("바코드 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("이 기기에서는 바코드 스캔을\n사용할 수 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("카메라 권한을 확인하거나 직접 검색해주세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }

    private func handleScan(_ code: String) {
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty else { return }
        onScanned(digits)
    }
}

// MARK: - DataScannerRepresentable

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        try? scanner.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScanned: (String) -> Void
        private var didScan = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !didScan else { return }
            for item in items {
                if case let .barcode(barcode) = item,
                   let payload = barcode.payloadStringValue,
                   payload.contains(where: \.isNumber) {
                    didScan = true
                    onScanned(payload)
                    return
                }
            }
        }
    }
}
