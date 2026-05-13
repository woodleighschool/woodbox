//
//  BulkScannerView.swift
//  WoodBox
//
//  Created by Alexander Hyde on 27/2/2026.
//

import SwiftData
import SwiftUI

#if os(iOS)

  struct BulkScannerView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Environment(ModelData.self) private var modelData

    @Query(sort: [SortDescriptor(\BulkScanHistoryItem.scannedAt, order: .reverse)])
    private var scanHistory: [BulkScanHistoryItem]

    @Query(sort: [SortDescriptor(\SnipeItStatus.name)])
    private var snipeStatuses: [SnipeItStatus]

    @State private var alertItem: AlertItem?
    @State private var isBusy = false
    @State private var isScanningPresented = false
    @State private var showClearConfirmation = false
    @State private var showDeleteMDMConfirmation = false
    @State private var scanFeedback = false
    @State private var currentOperationItems: [BulkOperationItem] = []
    @State private var currentOperationTitle = ""
    @State private var isOperationSheetPresented = false

    private static let csvFormatter = ISO8601DateFormatter()
    private static let exportFilenameFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = .current
      formatter.dateFormat = "yyyy-MM-dd_HHmmss"
      return formatter
    }()

    // MARK: - Computed Properties

    private var settings: AppSettings {
      modelData.settings
    }

    private var scannedDevices: [Device] {
      scanHistory.map(\.device)
    }

    private var hasMDMRecords: Bool {
      scannedDevices.contains { !$0.mdmRecords.isEmpty }
    }

    private var snipeStatusActions: [SnipeStatusAction] {
      snipeStatuses.map { SnipeStatusAction(title: $0.name, statusId: $0.snipeItId) }
    }

    private var exportCSV: String {
      var rows = ["Serial,Asset Tag,Scanned At"]

      for entry in scanHistory.reversed() {
        let device = entry.device
        let scannedAt = Self.csvFormatter.string(from: entry.scannedAt)
        let fields = [device.serial, device.assetTag, scannedAt]
        rows.append(fields.map(csvEscape).joined(separator: ","))
      }

      return rows.joined(separator: "\n")
    }

    private var actionMenuDisabled: Bool {
      scanHistory.isEmpty || isBusy
    }

    // MARK: - Body

    var body: some View {
      reviewContent
        .navigationTitle("Bulk Scanner")
        .toolbar { toolbarContent }
        .confirmationDialog("Clear all scanned devices?", isPresented: $showClearConfirmation) {
          Button("Clear All", role: .destructive, action: clearHistory)
          Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
          "Delete scanned devices from MDM?", isPresented: $showDeleteMDMConfirmation
        ) {
          Button("Delete from MDM", role: .destructive) { Task { await deleteMDM() } }
          Button("Cancel", role: .cancel) {}
        }
        .alert(item: $alertItem) { item in
          Alert(
            title: Text(item.title),
            message: Text(item.message),
            dismissButton: .default(Text("OK"))
          )
        }
        .sheet(isPresented: $isScanningPresented) {
          scannerSheet
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isOperationSheetPresented) {
          operationSheet
            .interactiveDismissDisabled(isBusy)
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var reviewContent: some View {
      if scanHistory.isEmpty {
        ContentUnavailableView {
          Label("No Devices Scanned", systemImage: "barcode.viewfinder")
        } description: {
          Text("Scan an asset tag barcode or serial number.")
        } actions: {
          Button {
            isScanningPresented = true
          } label: {
            Label("Start Scanning", systemImage: "camera.viewfinder")
          }
          .buttonStyle(.borderedProminent)
        }
      } else {
        List(scanHistory) { entry in
          DeviceSummaryItem(device: entry.device)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button("Remove", systemImage: "trash", role: .destructive) {
                removeHistory(entry)
              }
            }
        }
      }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isScanningPresented = true
        } label: {
          Image(systemName: "camera.viewfinder")
        }
        .disabled(isBusy)
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Clear", systemImage: "trash", role: .destructive) {
            showClearConfirmation = true
          }

          if let exportURL = makeExportFileURL() {
            ShareLink(item: exportURL, subject: Text("Scanned Devices")) {
              Label("Export", systemImage: "square.and.arrow.up")
            }
          }

          if settings.snipeItIsEnabled,
             settings.snipeItClient != nil,
             !snipeStatusActions.isEmpty
          {
            Section("Update Snipe-IT Status") {
              ForEach(snipeStatusActions) { action in
                Button(action.title) { Task { await updateSnipeStatus(action) } }
              }
            }
          }

          if hasMDMRecords {
            Divider()
            Button("Delete from MDM", systemImage: "iphone.slash", role: .destructive) {
              showDeleteMDMConfirmation = true
            }
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .disabled(actionMenuDisabled)
      }
    }

    // MARK: - Private Helpers

    private var scannerSheet: some View {
      DeviceScanner(
        title: "Scan asset tag or serial",
        subtitle: "Keep device centered in the frame",
        trigger: scanFeedback,
        onClose: { isScanningPresented = false },
        onCandidate: handleCandidate
      )
    }

    private func makeExportFileURL() -> URL? {
      let filename = "bulk-scanner-\(Self.exportFilenameFormatter.string(from: .now)).csv"
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

      guard let data = exportCSV.data(using: .utf8) else { return nil }

      do {
        try data.write(to: url, options: .atomic)
        return url
      } catch {
        return nil
      }
    }

    private var operationSheet: some View {
      NavigationStack {
        List(currentOperationItems) { item in
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
              Text(item.device.serial)
                .font(.headline)
              if let details = item.details {
                Text(details)
                  .font(.caption)
                  .foregroundStyle(item.status == .failed ? .red : .secondary)
              }
            }

            Spacer(minLength: 8)

            switch item.status {
            case .pending:
              Image(systemName: "circle")
                .foregroundStyle(.secondary)
            case .processing:
              ProgressView().controlSize(.small)
            case .success:
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            case .failed:
              Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            case .skipped:
              Image(systemName: "arrow.uturn.forward.circle.fill")
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 2)
        }
        .navigationTitle(currentOperationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            if !isBusy {
              Button("Done") {
                isOperationSheetPresented = false
              }
            } else {
              ProgressView().controlSize(.regular)
            }
          }
        }
      }
    }

    @MainActor
    private func handleCandidate(_ value: String, type scanType: ScanType) {
      guard !isBusy, !value.isEmpty else { return }

      guard let device = modelContext.fetchDevice(matching: value, scanType: scanType) else {
        alertItem = AlertItem(
          title: "Device Not Found",
          message: "No device with \(scanType.label) “\(value)” was found."
        )
        return
      }

      if upsertHistory(device) {
        scanFeedback.toggle()
      }
    }

    @MainActor
    private func upsertHistory(_ device: Device) -> Bool {
      guard scanHistory.first(where: { $0.device == device }) == nil else {
        return false // ignore repeats entirely
      }

      modelContext.insert(BulkScanHistoryItem(device: device))
      try? modelContext.save()
      return true
    }

    @MainActor
    private func removeHistory(_ entry: BulkScanHistoryItem) {
      modelContext.delete(entry)
      try? modelContext.save()
    }

    @MainActor
    private func clearHistory() {
      scanHistory.forEach(modelContext.delete)
      try? modelContext.save()
    }

    @MainActor
    private func updateSnipeStatus(_ action: SnipeStatusAction) async {
      guard let client = settings.snipeItClient else { return }

      await withBusyState {
        guard !scanHistory.isEmpty else { return }

        currentOperationTitle = "Updating Snipe-IT Status"
        currentOperationItems = scanHistory.map {
          BulkOperationItem(id: $0.id, device: $0.device, status: .pending)
        }
        isOperationSheetPresented = true

        for index in currentOperationItems.indices {
          let item = currentOperationItems[index]
          let device = item.device

          guard let assetId = device.snipeItId else {
            currentOperationItems[index].status = .skipped
            currentOperationItems[index].details = "No Snipe-IT ID"
            continue
          }

          currentOperationItems[index].status = .processing

          do {
            if device.assignedUserName != nil || device.assignedUserEmail != nil {
              try await client.checkinSnipeItAsset(
                assetId: assetId,
                request: SnipeItCheckinRequest(
                  statusId: action.statusId,
                  name: nil,
                  note: nil,
                  locationId: nil
                )
              )
            } else {
              try await client.updateSnipeItAsset(
                assetId: assetId,
                request: SnipeItUpdateRequest(
                  statusId: action.statusId,
                  notes: nil,
                  customFields: nil
                )
              )
            }
            device.statusId = action.statusId
            device.status = action.title
            device.assignedUserName = nil
            device.assignedUserEmail = nil
            currentOperationItems[index].status = .success
          } catch {
            currentOperationItems[index].status = .failed
            currentOperationItems[index].details = error.localizedDescription
          }
        }
      }
    }

    @MainActor
    private func deleteMDM() async {
      await withBusyState {
        guard hasMDMRecords else { return }

        currentOperationTitle = "Deleting from MDM"
        currentOperationItems = scanHistory.map {
          BulkOperationItem(id: $0.id, device: $0.device, status: .pending)
        }
        isOperationSheetPresented = true

        for index in currentOperationItems.indices {
          let item = currentOperationItems[index]
          let device = item.device

          guard !device.mdmRecords.isEmpty else {
            currentOperationItems[index].status = .skipped
            currentOperationItems[index].details = "No MDM records"
            continue
          }

          currentOperationItems[index].status = .processing

          var hasError = false
          for record in device.mdmRecords {
            do {
              try await MDMDeletionService.deleteAndRemove(
                record: record,
                from: device,
                modelContext: modelContext
              )
            } catch {
              hasError = true
            }
          }

          currentOperationItems[index].status = hasError ? .failed : .success
          if hasError {
            currentOperationItems[index].details = "Deletion failed"
          }
        }
      }
    }

    @MainActor
    private func withBusyState(_ operation: () async -> Void) async {
      guard !isBusy else { return }
      isBusy = true
      defer { isBusy = false }
      await operation()
    }

    private func csvEscape(_ value: String) -> String {
      "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
  }

  // MARK: - Supporting Types

  private enum OperationStatus: Equatable {
    case pending
    case processing
    case success
    case failed
    case skipped
  }

  private struct BulkOperationItem: Identifiable {
    var id: PersistentIdentifier
    let device: Device
    var status: OperationStatus
    var details: String?
  }

  private struct SnipeStatusAction: Identifiable {
    let title: String
    let statusId: Int

    var id: Int {
      statusId
    }
  }

#endif
