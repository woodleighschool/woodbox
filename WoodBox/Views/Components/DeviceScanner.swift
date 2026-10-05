import SwiftData
import SwiftUI

#if os(iOS)
  import Vision
  import VisionKit

  struct DeviceScanner: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var session: DeviceScanSession
    let title: String
    let subtitle: String
    let showsCount: Bool
    let onDevice: (Device) -> Void

    @State private var lookup: DeviceScanLookup?
    @State private var choices: [Device] = []
    @State private var failure: String?

    var body: some View {
      DeviceScannerCameraView(onCandidates: handleCandidates, onFailure: { failure = $0 })
        .ignoresSafeArea(edges: .bottom)
        .overlay {
          if let failure {
            ContentUnavailableView(
              "Unable to Scan",
              systemImage: "camera.badge.ellipsis",
              description: Text(failure)
            )
            .background()
          }
        }
        .overlay(alignment: .bottom) {
          if !choices.isEmpty {
            choicePicker
          }
        }
        .toolbar {
          ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
              heading
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
              status
                .font(.footnote)
                .contentTransition(.opacity)
            }
            .animation(.easeInOut(duration: 0.2), value: session.feedback)
          }
        }
        .toolbarTitleDisplayMode(.inline)
        .task {
          do {
            lookup = try DeviceScanLookup(devices: modelContext.fetch(FetchDescriptor<Device>()))
          } catch {
            failure = "Unable to load devices: \(error.localizedDescription)"
          }
        }
    }

    private var heading: Text {
      let count = session.addedSerials.count
      return showsCount && count > 0 ? Text("^[\(count) device](inflect: true) added") : Text(title)
    }

    @ViewBuilder
    private var status: some View {
      if let feedback = session.feedback, feedback.isSuccess {
        Label(feedback.message, systemImage: "checkmark.circle.fill")
          .labelStyle(.titleAndIcon)
          .foregroundStyle(.green)
      } else {
        Text(session.feedback?.message ?? subtitle)
          .foregroundStyle(.secondary)
      }
    }

    /// OCR matched more than one device; only the operator can tell which serial is in front of them.
    private var choicePicker: some View {
      VStack(spacing: 8) {
        Text("Check the serial and choose a device").font(.headline)
        ForEach(choices) { device in
          Button {
            choices = []
            onDevice(device)
          } label: {
            VStack {
              Text(device.serial).font(.body.monospaced())
              Text("Asset Tag \(device.assetTag)").font(.caption)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }
      .padding()
      .glassEffect(.regular, in: .rect(cornerRadius: 20))
      .padding()
    }

    private func handleCandidates(_ scans: [DeviceScan]) {
      guard let lookup else { return }
      // Prefer a known identifier over unrelated words printed beside the serial.
      guard let scan = scans.first(where: { !lookup.matches($0).isEmpty }) ?? scans.first,
            session.accepts(scan)
      else { return }
      let matches = lookup.matches(scan)
      switch matches.count {
      case 0:
        choices = []
        switch scan {
        case let .barcode(value), let .text(value):
          session.report("No match for \(value)")
        }
      case 1:
        choices = []
        onDevice(matches[0])
      default:
        choices = matches.sorted { $0.serial < $1.serial }
      }
    }
  }

  struct DeviceScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var selection: DeviceSelectionState
    @State private var session = DeviceScanSession()

    var body: some View {
      NavigationStack {
        DeviceScanner(
          session: $session,
          title: "Scan asset tag or serial",
          subtitle: "Align the code in the frame",
          showsCount: false
        ) { device in
          session.added(serial: device.serial, label: device.assetTag)
          selection.select(device)
          dismiss()
        }
      }
      .sensoryFeedback(.success, trigger: session.addedSerials.count)
    }
  }

  /// Keeps the scan button beside the search field, which sits in the bottom bar at compact width
  /// and in the navigation bar otherwise.
  struct ScanSearchToolbar: ToolbarContent {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let scan: () -> Void

    var body: some ToolbarContent {
      DefaultToolbarItem(kind: .search, placement: .bottomBar)
      ToolbarSpacer(.fixed, placement: .bottomBar)
      ToolbarItem(placement: horizontalSizeClass == .compact ? .bottomBar : .topBarTrailing) {
        Button("Scan", systemImage: "camera.viewfinder", action: scan)
      }
    }
  }

  /// VisionKit owns camera recognition; workflow and feedback state stay in SwiftUI.
  private struct DeviceScannerCameraView: UIViewControllerRepresentable {
    var onCandidates: ([DeviceScan]) -> Void
    var onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onCandidates: onCandidates, onFailure: onFailure)
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
      context.coordinator.start(scanner)
      return scanner
    }

    func updateUIViewController(_: DataScannerViewController, context: Context) {
      context.coordinator.onCandidates = onCandidates
      context.coordinator.onFailure = onFailure
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
      coordinator.startTask?.cancel()
      scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
      var onCandidates: ([DeviceScan]) -> Void
      var onFailure: (String) -> Void
      var startTask: Task<Void, Never>?

      init(onCandidates: @escaping ([DeviceScan]) -> Void, onFailure: @escaping (String) -> Void) {
        self.onCandidates = onCandidates
        self.onFailure = onFailure
      }

      func start(_ scanner: DataScannerViewController) {
        startTask = Task {
          guard !Task.isCancelled else { return }
          do {
            try scanner.startScanning()
          } catch {
            onFailure("Camera unavailable. Check camera access in Settings.")
          }
        }
      }

      func dataScanner(_: DataScannerViewController, didAdd items: [RecognizedItem], allItems _: [RecognizedItem]) {
        recognize(items)
      }

      func dataScanner(_: DataScannerViewController, didUpdate items: [RecognizedItem], allItems _: [RecognizedItem]) {
        recognize(items)
      }

      func dataScanner(_: DataScannerViewController, becameUnavailableWithError _: DataScannerViewController.ScanningUnavailable) {
        onFailure("Camera unavailable. Close and reopen the scanner to try again.")
      }

      private func recognize(_ items: [RecognizedItem]) {
        var barcodes: [DeviceScan] = []
        var text: [DeviceScan] = []
        for item in items {
          switch item {
          case let .barcode(barcode):
            if let value = barcode.payloadStringValue?.nilIfEmpty {
              barcodes.append(.barcode(value))
            }
          case let .text(item):
            text.append(contentsOf: DeviceScan.serialCandidates(in: item.transcript).map(DeviceScan.text))
          @unknown default: break
          }
        }
        onCandidates(barcodes + text)
      }
    }
  }
#endif
