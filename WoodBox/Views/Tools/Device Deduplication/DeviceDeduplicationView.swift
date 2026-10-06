import SwiftData
import SwiftUI

struct DeviceDeduplicationView: View {
  // MARK: - Properties

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  @Query(filter: #Predicate<Device> { $0.mdmRecords.count > 1 }, sort: \Device.serial)
  private var duplicates: [Device]

  @State private var alertItem: AlertItem?

  // MARK: - Body

  var body: some View {
    List {
      if duplicates.isEmpty {
        ContentUnavailableView(
          "No Duplicates",
          systemImage: "checkmark.circle",
          description: Text("No devices found with multiple MDM records.")
        )
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
      } else {
        ForEach(duplicates, id: \.serial) { device in
          DuplicateGroupSection(device: device, settings: modelData.settings) { record in
            Task {
              await delete(record, from: device)
            }
          }
        }
      }
    }
    .cacheRefreshable()
    .alert(item: $alertItem) { item in
      Alert(
        title: Text(item.title),
        message: Text(item.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  // MARK: - Private Methods

  private func delete(_ record: MDMRecord, from device: Device) async {
    let request = MDMDeletionService.Request(record: record)
    let localRecord = MDMDeletionService.LocalRecord(record: record)

    do {
      try MDMDeletionService.removeLocally(request, from: device, modelContext: modelContext)
    } catch {
      alertItem = .error(error)
      return
    }

    do {
      try await MDMDeletionService.delete(request)
    } catch {
      do {
        try MDMDeletionService.restoreLocally(
          localRecord,
          to: device,
          modelContext: modelContext
        )
        alertItem = .error(error)
      } catch let restoreError {
        alertItem = AlertItem(
          title: "Deletion Failed",
          message: "\(error.localizedDescription) The local record could not be restored: \(restoreError.localizedDescription)"
        )
      }
      return
    }

    do {
      // A concurrent refresh may have reintroduced the record during the remote delete.
      try MDMDeletionService.removeLocally(request, from: device, modelContext: modelContext)
    } catch {
      alertItem = .error(error)
    }
  }
}

// MARK: - Subviews

struct DuplicateGroupSection: View {
  let device: Device
  let settings: AppSettings
  let onDelete: (MDMRecord) -> Void

  private var sortedRecords: [MDMRecord] {
    device.mdmRecords.sorted {
      ($0.lastCheckIn ?? .distantPast) > ($1.lastCheckIn ?? .distantPast)
    }
  }

  var body: some View {
    Section {
      let latestId = sortedRecords.first?.id
      ForEach(sortedRecords, id: \.id) { record in
        DuplicateRecordRow(record: record, isLatest: record.id == latestId, settings: settings) {
          onDelete(record)
        }
      }
    } header: {
      HStack(spacing: 8) {
        Image(systemName: device.symbolName)
        Label(device.serial, systemImage: "number")
        Label(device.assetTag, systemImage: "barcode")
      }
    }
  }
}

struct DuplicateRecordRow: View {
  let record: MDMRecord
  let isLatest: Bool
  let settings: AppSettings
  let onDelete: () -> Void

  #if os(iOS)
    @Environment(\.openURL) private var openURL
  #endif

  var body: some View {
    HStack(spacing: 16) {
      details

      Spacer(minLength: 8)

      #if os(macOS)
        if let url = mdmURL {
          Link(destination: url) {
            Label("Open", systemImage: "safari")
          }
          .buttonStyle(.borderless)
        }

        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .help("Delete this MDM record")
      #endif
    }
    #if os(iOS)
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
      if let url = mdmURL {
        Button("Open in Browser", systemImage: "safari") {
          openURL(url)
        }
        .tint(.blue)
      }
    }
    #endif
  }

  private var details: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      // The gutter stays reserved so every record's text lines up.
      ZStack {
        if isLatest {
          PingBadge()
            .accessibilityLabel("Latest record")
        }
      }
      .frame(width: 10)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          DeviceNameText(name: record.deviceName)
            .font(.body.weight(.medium))
            .layoutPriority(1)

          Group {
            Text(record.provider.rawValue)
            Text(record.deviceId)
              .monospaced()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .lineLimit(1)

        if let date = record.lastCheckIn {
          Text(
            "Last seen \(date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var mdmURL: URL? {
    switch record.provider {
    case .intune:
      return URL(
        string:
        "https://intune.microsoft.com/#view/Microsoft_Intune_Devices/DeviceSettingsMenuBlade/~/overview/mdmDeviceId/\(record.deviceId)"
      )
    case .jamf:
      let endpoint = record.jamfDeviceType == .mobile ? "mobileDevices.html" : "computers.html"
      return URL(string: "\(settings.jamfBaseURL)/\(endpoint)?id=\(record.deviceId)")
    }
  }
}

struct PingBadge: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isPinging = false

  var body: some View {
    ZStack {
      Circle()
        .fill(.green.opacity(0.35))
        .frame(width: 10, height: 10)
        .scaleEffect(isPinging ? 2.2 : 1)
        .opacity(isPinging ? 0 : 1)
        .animation(
          reduceMotion ? nil : .easeOut(duration: 1.2).repeatForever(autoreverses: false),
          value: isPinging
        )

      Circle()
        .fill(.green)
        .frame(width: 10, height: 10)
    }
    .onAppear {
      isPinging = !reduceMotion
    }
    .onChange(of: reduceMotion) { _, reduceMotion in
      isPinging = !reduceMotion
    }
  }
}
