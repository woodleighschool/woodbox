import SwiftUI

struct DeviceProcessingCapture: Identifiable {
  enum Start {
    case scanner
    case condition(Device)
  }

  let id = UUID()
  let start: Start
}

struct DeviceProcessingCaptureView: View {
  private enum Phase {
    case scanner
    case condition(Device)
  }

  #if os(iOS)
    let profile: DeviceProcessingProfile
    let candidate: (String, ScanType) throws -> Device
  #endif
  let commit: (DeviceProcessingDraft) throws -> Void

  @State private var phase: Phase
  @State private var grade: SaleGrade?
  @State private var notes = ""
  @State private var feedbackTrigger = 0
  @State private var alertItem: AlertItem?

  @Environment(\.dismiss) private var dismiss

  private let returnsToScanner: Bool

  #if os(iOS)
    init(
      profile: DeviceProcessingProfile,
      start: DeviceProcessingCapture.Start,
      candidate: @escaping (String, ScanType) throws -> Device,
      commit: @escaping (DeviceProcessingDraft) throws -> Void
    ) {
      self.profile = profile
      self.candidate = candidate
      self.commit = commit

      switch start {
      case .scanner:
        _phase = State(initialValue: .scanner)
        returnsToScanner = true
      case let .condition(device):
        _phase = State(initialValue: .condition(device))
        returnsToScanner = false
      }
    }
  #else
    init(
      start: DeviceProcessingCapture.Start,
      commit: @escaping (DeviceProcessingDraft) throws -> Void
    ) {
      self.commit = commit

      switch start {
      case .scanner:
        _phase = State(initialValue: .scanner)
        returnsToScanner = true
      case let .condition(device):
        _phase = State(initialValue: .condition(device))
        returnsToScanner = false
      }
    }
  #endif

  var body: some View {
    NavigationStack {
      content
    }
    .alert(item: $alertItem) { item in
      Alert(
        title: Text(item.title),
        message: Text(item.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .scanner:
      #if os(iOS)
        DeviceScanner(
          title: "Scan Devices",
          subtitle: profile.requiresCondition
            ? "Grade each device as you scan"
            : "Keep scanning to build the queue",
          trigger: feedbackTrigger,
          onCandidate: handleCandidate
        )
        .transition(.move(edge: .leading).combined(with: .opacity))
      #else
        EmptyView()
      #endif

    case let .condition(device):
      SaleConditionForm(
        device: device,
        name: device.name,
        assetTag: device.assetTag,
        serial: device.serial,
        model: device.model,
        grade: $grade,
        notes: $notes
      )
      .navigationTitle("Sale Condition")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
      #endif
        .toolbar {
          if returnsToScanner {
            ToolbarItem(placement: .cancellationAction) {
              Button("Scan", systemImage: "chevron.backward", action: showScanner)
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              save(device)
            }
            .disabled(grade == nil)
          }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
  }

  #if os(iOS)
    private func handleCandidate(_ value: String, type: ScanType) {
      do {
        let device = try candidate(value, type)
        switch profile {
        case .restock:
          try commit(.restock(device))
          feedbackTrigger += 1
        case .sale:
          grade = nil
          notes = ""
          withAnimation(.snappy) {
            phase = .condition(device)
          }
        }
      } catch {
        alertItem = AlertItem(title: "Unable to Add Device", message: error.localizedDescription)
      }
    }
  #endif

  private func showScanner() {
    grade = nil
    notes = ""
    withAnimation(.snappy) {
      phase = .scanner
    }
  }

  private func save(_ device: Device) {
    guard let grade else { return }

    do {
      try commit(.sale(device, grade: grade, conditionNotes: notes))
      feedbackTrigger += 1
      self.grade = nil
      notes = ""
      if returnsToScanner {
        withAnimation(.snappy) {
          phase = .scanner
        }
      } else {
        dismiss()
      }
    } catch {
      alertItem = AlertItem(title: "Unable to Add Device", message: error.localizedDescription)
    }
  }
}
