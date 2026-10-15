import SwiftData
import SwiftUI

struct DeviceDeduplicationView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData
  @State private var alertItem: AlertItem?

  private var state: DeduplicationState {
    modelData.deduplication
  }

  private var hasProvider: Bool {
    modelData.settings.jamfIsEnabled || modelData.settings.intuneIsEnabled
  }

  var body: some View {
    Group {
      if !hasProvider {
        ContentUnavailableView(
          "No MDM Connection",
          systemImage: "network",
          description: Text("Enable Jamf or Intune in Settings.")
        )
      } else {
        List {
          if state.hasLoaded, state.groups.isEmpty {
            ContentUnavailableView(
              "No Duplicates",
              systemImage: "rectangle.on.rectangle.slash",
              description: Text("No serial numbers have multiple MDM records.")
            )
            .listRowBackground(Color.clear)
          }
          ForEach(state.groups) { group in
            DuplicateGroupSection(
              group: group,
              device: modelContext.fetchDevice(serial: group.serial),
              settings: modelData.settings,
              deleting: state.deleting,
              isRefreshing: state.loadState.isLoading
            ) { record in
              Task {
                do { try await state.delete(record) }
                catch { alertItem = .error(error) }
              }
            }
          }
        }
        .overlay {
          if !state.hasLoaded {
            ToolLoadingView(title: "Loading MDM records", state: state.loadState)
              .allowsHitTesting(false)
          }
        }
      }
    }
    .toolRefreshable(state: state.loadState, failurePolicy: modelData.deduplicationRefreshFailures, disabled: !hasProvider || !state.deleting.isEmpty) { _ in
      await state.refresh()
      return state.loadState
    }
    .alert(item: $alertItem) { item in
      Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
    }
  }
}

private struct DuplicateGroupSection: View {
  let group: DuplicateGroup
  let device: Device?
  let settings: AppSettings
  let deleting: Set<String>
  let isRefreshing: Bool
  let onDelete: (MDMRecord) -> Void

  var body: some View {
    Section {
      ForEach(group.records) { record in
        DuplicateRecordRow(
          record: record,
          settings: settings,
          isDeleting: deleting.contains(record.id),
          isRefreshing: isRefreshing
        ) { onDelete(record) }
      }
    } header: {
      DeviceIdentityLabel(
        device: device,
        name: device?.name,
        model: device?.model ?? group.records.compactMap(\.model).first ?? "Model not reported",
        assetTag: device?.assetTag,
        serial: group.serial
      )
      .textCase(nil)
    }
  }
}

private struct DuplicateRecordRow: View {
  let record: MDMRecord
  let settings: AppSettings
  let isDeleting: Bool
  let isRefreshing: Bool
  let onDelete: () -> Void

  #if os(iOS)
    @Environment(\.openURL) private var openURL
  #endif

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(record.provider.rawValue).font(.headline)
        DeviceNameText(name: record.deviceName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text("Record ID \(record.deviceId)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        if let date = record.lastCheckIn {
          Text("Last reported \(date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 8)
      if isDeleting {
        ProgressView().controlSize(.small)
      }
      #if os(macOS)
        if let url = mdmURL {
          Link("Open", destination: url).buttonStyle(.borderless)
        }
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .disabled(isDeleting || isRefreshing)
      #endif
    }
    #if os(iOS)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      // The destructive role animates removal before the async deletion finishes.
      Button("Delete", systemImage: "trash", action: onDelete)
        .tint(.red)
        .disabled(isDeleting || isRefreshing)
      if let url = mdmURL {
        Button("Open", systemImage: "safari") { openURL(url) }
      }
    }
    #endif
  }

  private var mdmURL: URL? {
    switch record.provider {
    case .intune:
      URL(string: "https://intune.microsoft.com/#view/Microsoft_Intune_Devices/DeviceSettingsMenuBlade/~/overview/mdmDeviceId/\(record.deviceId)")
    case .jamf:
      URL(string: "\(settings.jamfBaseURL)/\(record.jamfDeviceType == .mobile ? "mobileDevices.html" : "computers.html")?id=\(record.deviceId)")
    }
  }
}
