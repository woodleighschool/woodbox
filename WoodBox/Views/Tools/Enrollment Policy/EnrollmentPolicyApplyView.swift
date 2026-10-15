import SwiftUI

struct EnrollmentPolicyApplyView: View {
  private enum RunState {
    case ready
    case running
    case finished
  }

  @Environment(ModelData.self) private var modelData
  #if os(macOS)
    @Environment(\.dismiss) private var dismiss
  #endif

  let plan: EnrollmentAssignmentPlan

  @State private var activities: [String: OperationActivity]
  @State private var runState = RunState.ready

  init(plan: EnrollmentAssignmentPlan) {
    self.plan = plan
    _activities = State(initialValue: [:])
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          LabeledContent("Policy", value: plan.target.name)

        } header: {
          Text("Destination")
        } footer: {
          Text("Devices use the policy the next time they enroll.")
        }

        Section("Devices") {
          ForEach(plan.serials, id: \.self) { serial in
            HStack(spacing: 12) {
              EnrollmentDeviceLabel(
                serial: serial,
                enrolled: modelData.enrollmentQueue.snapshot?.devices[serial]
              ) {
                EmptyView()
              }
              OperationActivityLabel(activity: activities[serial] ?? .waiting)
            }
          }
        }
      }
      .navigationTitle("Assign Policy")
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
              Button("Apply", action: start)
                .buttonStyle(.borderedProminent)
                .disabled(plan.serials.isEmpty)
            }
          }
        }
    }
    .interactiveDismissDisabled(runState == .running)
    .task(id: runState) {
      guard runState == .running else { return }
      await assign()
    }
    #if os(macOS)
    .frame(minWidth: 480, minHeight: 400)
    #endif
  }

  private func start() {
    runState = .running
  }

  private func assign() async {
    let coordinator = EnrollmentCoordinator(service: LiveEnrollmentService(settings: modelData.settings))
    do {
      try await coordinator.assign(plan) { serial, activity in activities[serial] = activity }
    } catch {
      for serial in plan.serials where activities[serial] == nil || activities[serial] == .waiting {
        activities[serial] = .failed(error.localizedDescription)
      }
    }
    if !Task.isCancelled {
      await modelData.enrollmentQueue.refresh()
    }
    runState = .finished
  }
}
