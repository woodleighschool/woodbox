import SwiftData
import SwiftUI

nonisolated struct DeviceProcessingApplication: Identifiable, Sendable {
  let id = UUID()
  let statusId: Int
  let statusName: String
}

struct DeviceProcessingApplyView: View {
  private enum RunState: Equatable {
    case ready
    case running
    case finished
  }

  private enum Activity: Equatable {
    case waiting
    case working(String)
    case applied
    case failed(String)
  }

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  let items: [DeviceProcessingItem]
  let application: DeviceProcessingApplication

  @State private var activities: [String: Activity] = [:]
  @State private var runState = RunState.ready

  var body: some View {
    NavigationStack {
      List {
        Section("Destination") {
          LabeledContent("Apply Status", value: application.statusName)
        }

        Section {
          ForEach(items) { item in
            let device = device(for: item)
            DeviceIdentityLabel(
              device: device,
              name: item.deviceName,
              model: item.deviceModel,
              assetTag: item.assetTag,
              serial: item.serial
            ) {
              ActivityLabel(activity: activities[item.key] ?? .waiting)
            }
          }
        } header: {
          Text("Devices")
        } footer: {
          Text(footerMessage)
        }
      }
      .navigationTitle("Apply Status")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            if runState == .running {
              ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Applying status")
            } else if runState == .ready {
              Button("Apply", action: start)
                .buttonStyle(.borderedProminent)
            }
          }
        }
    }
    .interactiveDismissDisabled(runState == .running)
    .task(id: runState) {
      guard runState == .running else { return }
      await apply()
    }
    #if os(macOS)
    .frame(minWidth: 480, minHeight: 400)
    #endif
  }

  private var footerMessage: String {
    if runState == .finished {
      let failures = activities.values.count {
        if case .failed = $0 {
          true
        } else {
          false
        }
      }
      if failures == 0 {
        return "The status was applied to every device. The queue remains available for another operation or export."
      }
      return "\(failures) \(failures == 1 ? "device needs" : "devices need") attention. The queue remains unchanged."
    }

    let providers = items
      .compactMap(device(for:))
      .flatMap(\.mdmProviderNames)
    let providerNames = Array(Set(providers)).sorted()
    let deletionDescription = providerNames.isEmpty
      ? "No cached MDM records will be deleted."
      : "The devices will be deleted from \(providerNames.joined(separator: " and "))."

    return "\(deletionDescription) Snipe-IT status “\(application.statusName)” will then be applied."
  }

  private func start() {
    runState = .running
  }

  private func apply() async {
    let coordinator = DeviceProcessingCoordinator(
      service: LiveDeviceProcessingService(settings: modelData.settings),
      modelContext: modelContext
    )

    for item in items {
      guard !Task.isCancelled else { break }
      activities[item.key] = .working("Preparing")

      let outcome = await coordinator.process(
        item: item,
        device: device(for: item),
        targetStatusId: application.statusId,
        targetStatusName: application.statusName,
        conditionField: modelData.settings.snipeItConditionField,
        conditionNotesField: modelData.settings.snipeItConditionNotesField
      ) { message in
        activities[item.key] = .working(message)
      }

      switch outcome {
      case .applied:
        activities[item.key] = .applied
      case let .failed(message):
        activities[item.key] = .failed(message)
      }
    }

    if !Task.isCancelled {
      await modelData.cacheManager.sync()
    }
    runState = .finished
  }

  private func device(for item: DeviceProcessingItem) -> Device? {
    modelContext.fetchDevice(matching: item.serial, scanType: .serial)
  }

  private struct ActivityLabel: View {
    let activity: Activity

    var body: some View {
      HStack(spacing: 6) {
        switch activity {
        case .waiting:
          Image(systemName: "circle")
          Text("Waiting")
        case let .working(message):
          ProgressView().controlSize(.small)
          Text(message)
        case .applied:
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text("Applied")
        case let .failed(message):
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
          Text(message)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(2)
    }
  }
}
