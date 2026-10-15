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

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData
  #if os(macOS)
    @Environment(\.dismiss) private var dismiss
  #endif

  let items: [DeviceProcessingItem]
  let application: DeviceProcessingApplication

  @State private var activities: [String: OperationActivity] = [:]
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
            HStack(spacing: 12) {
              DeviceIdentityLabel(
                device: device,
                name: item.deviceName,
                model: item.deviceModel,
                assetTag: item.assetTag,
                serial: item.serial
              )
              OperationActivityLabel(activity: activities[item.serial] ?? .waiting)
            }
          }
        } header: {
          Text("Devices")
        } footer: {
          Text(footerMessage)
        }
      }
      .navigationTitle("Process Devices")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          #if os(macOS)
            ToolbarItem(placement: .cancellationAction) {
              Button(runState == .finished ? "Done" : "Cancel") {
                dismiss()
              }
              .disabled(runState == .running)
            }
          #endif
          ToolbarItem(placement: .confirmationAction) {
            if runState == .running {
              ProgressView()
                .controlSize(.small)
            } else if runState == .ready {
              Button("Process", action: start)
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

    return "Current records will be removed from enabled MDM services before applying the selected Snipe-IT status."
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
      activities[item.serial] = .working("Preparing")

      let outcome = await coordinator.process(
        item: item,
        device: device(for: item),
        targetStatusId: application.statusId,
        targetStatusName: application.statusName,
        conditionField: modelData.settings.snipeItConditionField,
        conditionNotesField: modelData.settings.snipeItConditionNotesField
      ) { message in
        activities[item.serial] = .working(message)
      }

      switch outcome {
      case .applied:
        activities[item.serial] = .applied
      case let .failed(message):
        activities[item.serial] = .failed(message)
      }
    }

    runState = .finished
  }

  private func device(for item: DeviceProcessingItem) -> Device? {
    modelContext.fetchDevice(serial: item.serial)
  }
}
