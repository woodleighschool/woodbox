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
        .refreshable {
          await modelData.cacheManager.sync()
        }
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
              Image(systemName: "clock")
                .foregroundStyle(.secondary)
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
          guard $0.device.snipeItId != nil else {
            return BulkOperationItem(
              id: $0.device.serial,
              device: $0.device,
              status: .skipped,
              details: "No Snipe-IT ID"
            )
          }

          return BulkOperationItem(
            id: $0.device.serial,
            device: $0.device,
            status: .success,
            details: "Queued"
          )
        }
        isOperationSheetPresented = true

        let workItems = scanHistory.compactMap { entry -> SnipeStatusWorkItem? in
          let device = entry.device
          guard let assetId = device.snipeItId else { return nil }
          let wasAssigned = device.assignedUserName != nil || device.assignedUserEmail != nil

          device.statusId = action.statusId
          device.status = action.title
          device.assignedUserName = nil
          device.assignedUserEmail = nil

          return SnipeStatusWorkItem(
            id: device.serial,
            assetId: assetId,
            wasAssigned: wasAssigned
          )
        }

        let failures = await updateSnipeStatusConcurrently(
          workItems,
          action: action,
          client: client
        )

        for failure in failures {
          if let index = currentOperationItems.firstIndex(where: { $0.id == failure.id }) {
            currentOperationItems[index].status = .failed
            currentOperationItems[index].details = failure.message
          }
        }

        for index in currentOperationItems.indices
          where currentOperationItems[index].details == "Queued"
        {
          currentOperationItems[index].details = nil
        }
      }
    }

    private func updateSnipeStatusConcurrently(
      _ workItems: [SnipeStatusWorkItem],
      action: SnipeStatusAction,
      client: SnipeITClient
    ) async -> [OperationFailure] {
      await withTaskGroup(of: OperationFailure?.self) { group in
        for item in workItems {
          group.addTask {
            do {
              if item.wasAssigned {
                try await client.checkinSnipeItAsset(
                  assetId: item.assetId,
                  request: SnipeItCheckinRequest(
                    statusId: action.statusId,
                    name: nil,
                    note: nil,
                    locationId: nil
                  )
                )
              } else {
                try await client.updateSnipeItAsset(
                  assetId: item.assetId,
                  request: SnipeItUpdateRequest(
                    statusId: action.statusId,
                    notes: nil,
                    customFields: nil
                  )
                )
              }
              return nil
            } catch {
              return OperationFailure(id: item.id, message: error.localizedDescription)
            }
          }
        }

        var failures: [OperationFailure] = []
        for await failure in group {
          if let failure {
            failures.append(failure)
          }
        }
        return failures
      }
    }

    @MainActor
    private func deleteMDM() async {
      await withBusyState {
        guard hasMDMRecords else { return }

        currentOperationTitle = "Deleting from MDM"
        currentOperationItems = scanHistory.map {
          BulkOperationItem(
            id: $0.device.serial,
            device: $0.device,
            status: $0.device.mdmRecords.isEmpty ? .skipped : .success,
            details: $0.device.mdmRecords.isEmpty ? "No MDM records" : "Queued"
          )
        }
        isOperationSheetPresented = true

        let requestItems = scanHistory.flatMap { entry -> [MDMDeletionWorkItem] in
          let device = entry.device
          let requests = MDMDeletionService.remove(
            records: Array(device.mdmRecords),
            from: device,
            modelContext: modelContext
          )
          return requests.map { MDMDeletionWorkItem(id: device.serial, request: $0) }
        }

        let failures = await deleteMDMConcurrently(requestItems)

        for failure in failures {
          if let index = currentOperationItems.firstIndex(where: { $0.id == failure.id }) {
            currentOperationItems[index].status = .failed
            currentOperationItems[index].details = failure.message
          }
        }

        for index in currentOperationItems.indices
          where currentOperationItems[index].details == "Queued"
        {
          currentOperationItems[index].details = nil
        }
      }
    }

    private func deleteMDMConcurrently(_ workItems: [MDMDeletionWorkItem]) async
      -> [OperationFailure]
    {
      await withTaskGroup(of: OperationFailure?.self) { group in
        for item in workItems {
          group.addTask {
            do {
              try await MDMDeletionService.delete(item.request)
              return nil
            } catch {
              return OperationFailure(id: item.id, message: error.localizedDescription)
            }
          }
        }

        var failures: [OperationFailure] = []
        for await failure in group {
          if let failure {
            failures.append(failure)
          }
        }
        return failures
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
    case success
    case failed
    case skipped
  }

  private struct BulkOperationItem: Identifiable {
    var id: String
    let device: Device
    var status: OperationStatus
    var details: String?
  }

  private struct SnipeStatusWorkItem {
    let id: String
    let assetId: Int
    let wasAssigned: Bool
  }

  private struct MDMDeletionWorkItem {
    let id: String
    let request: MDMDeletionService.Request
  }

  private struct OperationFailure {
    let id: String
    let message: String
  }

  private struct SnipeStatusAction: Identifiable {
    let title: String
    let statusId: Int

    var id: Int {
      statusId
    }
  }

#endif
