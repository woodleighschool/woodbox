import SwiftData
import SwiftUI

#if os(iOS)
  import Vision
  import VisionKit

  // MARK: - DeviceScanner

  struct DeviceScanner<Trigger: Equatable>: View {
    // MARK: - Properties

    let title: String
    let subtitle: String
    let trigger: Trigger
    let onClose: () -> Void
    let onCandidate: (String, ScanType) -> Void

    // MARK: - Body

    var body: some View {
      DeviceScannerCameraView(onCandidate: onCandidate)
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
          ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
              Text(title).font(.headline)
              Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
          }
          ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: onClose)
              .labelStyle(.iconOnly)
          }
        }
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: trigger)
    }
  }

  // MARK: - DeviceScannerSheet

  struct DeviceScannerSheet: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var selection: DeviceSelectionState

    @State private var notFoundAlert: AlertItem?
    @State private var scanFeedback = false

    // MARK: - Body

    var body: some View {
      NavigationStack {
        DeviceScanner(
          title: "Scan asset tag or serial",
          subtitle: "Align the code in the frame",
          trigger: scanFeedback,
          onClose: { dismiss() },
          onCandidate: handleCandidate
        )
      }
      .alert(item: $notFoundAlert) { item in
        Alert(
          title: Text(item.title),
          message: Text(item.message),
          dismissButton: .cancel(Text("Close"))
        )
      }
    }

    // MARK: - Private Helpers

    @MainActor
    private func handleCandidate(_ value: String, type scanType: ScanType) {
      guard let device = modelContext.fetchDevice(matching: value, scanType: scanType) else {
        notFoundAlert = AlertItem(
          title: "Device Not Found",
          message: "No device with \(scanType.label) \"\(value)\" was found."
        )
        return
      }

      let isNewSelection = selection.selectedDevice != device
      selection.select(device)

      if isNewSelection {
        scanFeedback.toggle()
      }
      dismiss()
    }
  }

  // MARK: - DeviceScannerCameraView

  private struct DeviceScannerCameraView: UIViewControllerRepresentable {
    // MARK: - Properties

    var onCandidate: (String, ScanType) -> Void

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
      Coordinator(onCandidate: onCandidate)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
      let scanner = DataScannerViewController(
        recognizedDataTypes: [.barcode(symbologies: [.code39]), .text()],
        qualityLevel: .accurate,
        recognizesMultipleItems: false,
        isPinchToZoomEnabled: true,
        isGuidanceEnabled: false,
        isHighlightingEnabled: false
      )
      scanner.delegate = context.coordinator
      try? scanner.startScanning()
      return scanner
    }

    func updateUIViewController(_: DataScannerViewController, context _: Context) {}

    static func dismantleUIViewController(
      _ scanner: DataScannerViewController, coordinator _: Coordinator
    ) {
      scanner.stopScanning()
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
      // MARK: - Properties

      private let onCandidate: (String, ScanType) -> Void

      // MARK: - Init

      init(onCandidate: @escaping (String, ScanType) -> Void) {
        self.onCandidate = onCandidate
      }

      // MARK: - DataScannerViewControllerDelegate

      func dataScanner(
        _: DataScannerViewController, didAdd items: [RecognizedItem], allItems _: [RecognizedItem]
      ) {
        for item in items {
          switch item {
          case let .barcode(barcode):
            guard barcode.observation.symbology == .code39,
                  let value = barcode.payloadStringValue?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ),
                  !value.isEmpty
            else { continue }
            onCandidate(value, .assetTag)
            return

          case let .text(text):
            if let serial = firstSerialCandidate(in: text.transcript) {
              onCandidate(serial, .serial)
              return
            }

          @unknown default: break
          }
        }
      }

      // MARK: - Private Helpers

      private func firstSerialCandidate(in transcript: String) -> String? {
        transcript
          .split(separator: /\W+/)
          .map(String.init)
          .first {
            ($0.count == 10 || $0.count == 12)
              && $0.allSatisfy { $0.isUppercase || $0.isNumber }
              && $0.contains(where: \.isUppercase)
              && $0.contains(where: \.isNumber)
          }
      }
    }
  }

#endif
