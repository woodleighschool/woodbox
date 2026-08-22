import SwiftData
import SwiftUI

struct DeviceDeduplicationView: View {
  // MARK: - Properties

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  @Query(filter: #Predicate<Device> { $0.mdmRecords.count > 1 }, sort: \Device.serial)
  private var duplicates: [Device]

  @State private var pendingDeletion: (record: MDMRecord, device: Device)?
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
            pendingDeletion = (record, device)
          }
        }
      }
    }
    .refreshable {
      await modelData.cacheManager.sync()
    }
    .alert(
      "Confirm Deletion",
      isPresented: Binding(
        get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
      )
    ) {
      Button("Delete", role: .destructive) {
        guard let (record, device) = pendingDeletion else { return }
        Task { await delete(record, from: device) }
      }
      Button("Cancel", role: .cancel) { pendingDeletion = nil }
    } message: {
      if let provider = pendingDeletion?.record.provider.rawValue {
        Text("Are you sure you want to delete this record from \(provider)?")
      }
    }
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
    pendingDeletion = nil
    let requests = MDMDeletionService.remove(
      records: [record],
      from: device,
      modelContext: modelContext
    )

    let errors = await MDMDeletionService.delete(requests)
    if let error = errors.first {
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

  @Environment(\.openURL) private var openURL

  var body: some View {
    HStack(spacing: 16) {
      ZStack(alignment: .topTrailing) {
        Image(record.provider.rawValue.lowercased())
          .resizable()
          .scaledToFit()
          .frame(width: 24, height: 24)

        if isLatest { PingBadge().offset(x: 2, y: -2) }
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          DeviceNameText(name: record.deviceName)
            .font(.body.weight(.medium))
            .lineLimit(1)

          Text("\(record.deviceId)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        if let date = record.lastCheckIn {
          Text(
            "Last seen \(date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
      }
      if let url = mdmURL {
        Button {
          openURL(url)
        } label: {
          Image(systemName: "safari")
        }
        .tint(.blue)
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
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      Circle()
        .fill(.green.opacity(0.35))
        .frame(width: 10, height: 10)
        .scaleEffect(isAnimating ? 2.2 : 1.0)
        .opacity(isAnimating ? 0 : 1)
        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isAnimating)

      Circle()
        .fill(.green)
        .frame(width: 10, height: 10)
    }
    .onAppear { isAnimating = true }
  }
}
