import SwiftData
import SwiftUI

struct DeviceSearchResultLabel: View {
  let device: Device

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 3) {
        DeviceNameText(name: device.name)
        Text(device.model)
          .font(.caption)
          .foregroundStyle(.secondary)
        DeviceIdentifiersRow(assetTag: device.assetTag, serial: device.serial)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } icon: {
      Image(systemName: device.symbolName)
    }
  }
}

#if os(iOS)
  struct DeviceProcessingItemRow: View {
    let item: DeviceProcessingItem

    var body: some View {
      HStack(spacing: 12) {
        Image(systemName: Device.symbolName(for: item.deviceModel))
          .font(.title3)
          .frame(width: 32)
          .foregroundStyle(.tint)

        VStack(alignment: .leading, spacing: 3) {
          DeviceNameText(name: item.deviceName)
            .font(.headline)
          Text(item.deviceModel)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          DeviceIdentifiersRow(assetTag: item.assetTag, serial: item.serial)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

          if item.profile.requiresCondition {
            conditionDetails
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          if let errorMessage = item.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(.red)
              .lineLimit(2)
          }
        }

        Spacer(minLength: 8)
        DeviceProcessingStateView(item: item)
      }
      .padding(.vertical, 2)
    }

    private var conditionDetails: some View {
      HStack(spacing: 8) {
        if let grade = item.grade {
          Label("Grade \(grade.rawValue)", systemImage: "checkmark.seal")
        }

        if let notes = item.conditionNotes.nilIfEmpty {
          Label(notes, systemImage: "note.text")
        }
      }
    }
  }
#endif

struct DeviceProcessingStateView: View {
  let item: DeviceProcessingItem

  var body: some View {
    switch item.state {
    case .ready:
      Image(systemName: "circle")
        .foregroundStyle(.secondary)
        .accessibilityLabel("Ready")
    case .processing:
      ProgressView()
        .controlSize(.small)
        .accessibilityLabel(item.operationMessage ?? "Processing")
    case .completed:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .accessibilityLabel("Complete")
    case .failed:
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(.red)
        .accessibilityLabel("Failed")
    }
  }
}

struct SaleConditionForm: View {
  let assetTag: String
  let serial: String
  let model: String

  @Binding var grade: SaleGrade?
  @Binding var notes: String

  var body: some View {
    Form {
      Section("Device") {
        LabeledContent("Asset Tag", value: assetTag)
        LabeledContent("Serial", value: serial)
        LabeledContent("Model", value: model)
      }

      Section("Condition") {
        Picker("Grade", selection: $grade) {
          Text("Choose").tag(nil as SaleGrade?)
          ForEach(SaleGrade.allCases, id: \.self) { grade in
            Text(grade.rawValue).tag(grade as SaleGrade?)
          }
        }
        .pickerStyle(.segmented)

        TextField(
          "Condition Notes (Optional)",
          text: $notes,
          prompt: Text("Describe visible wear, damage, or missing parts"),
          axis: .vertical
        )
        .lineLimit(3 ... 6)
      }
    }
    .formStyle(.grouped)
  }
}

#if os(iOS)
  struct SaleConditionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: DeviceProcessingItem

    @State private var grade: SaleGrade?
    @State private var notes: String

    init(item: DeviceProcessingItem) {
      self.item = item
      _grade = State(initialValue: item.grade)
      _notes = State(initialValue: item.conditionNotes)
    }

    private var canSave: Bool {
      grade != nil
    }

    var body: some View {
      SaleConditionForm(
        assetTag: item.assetTag,
        serial: item.serial,
        model: item.deviceModel,
        grade: $grade,
        notes: $notes
      )
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Sale Condition")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled(!canSave)
        }
      }
    }

    private func save() {
      item.grade = grade
      item.conditionNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
      if item.state == .failed {
        item.prepareForRetry()
      }
      try? modelContext.save()
      dismiss()
    }
  }
#endif

#if os(macOS)
  struct DeviceProcessingTable: View {
    let items: [DeviceProcessingItem]
    let profile: DeviceProcessingProfile
    let onRemove: (DeviceProcessingItem) -> Void

    var body: some View {
      Table(items) {
        TableColumn("Device") { item in
          VStack(alignment: .leading, spacing: 2) {
            Text(item.deviceName.nilIfEmpty ?? item.assetTag)
            Text(item.deviceModel)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .width(min: 170, ideal: 220)

        TableColumn("Asset Tag", value: \.assetTag)
          .width(min: 90, ideal: 110)

        TableColumn("Serial", value: \.serial)
          .width(min: 110, ideal: 130)

        if profile.requiresCondition {
          TableColumn("Grade") { item in
            SaleGradeCell(item: item)
          }
          .width(70)

          TableColumn("Condition Notes") { item in
            SaleNotesCell(item: item)
          }
          .width(min: 180, ideal: 320)
        }

        TableColumn("Result") { item in
          HStack(spacing: 6) {
            DeviceProcessingStateView(item: item)
            Text(resultText(for: item))
              .lineLimit(1)
          }
        }
        .width(min: 110, ideal: 180)

        TableColumn("") { item in
          Button("Remove", systemImage: "trash", role: .destructive) {
            onRemove(item)
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .disabled(item.state == .processing)
        }
        .width(32)
      }
    }

    private func resultText(for item: DeviceProcessingItem) -> String {
      switch item.state {
      case .ready: "Ready"
      case .processing: item.operationMessage ?? "Processing"
      case .completed: "Complete"
      case .failed: item.errorMessage ?? "Failed"
      }
    }
  }

  private struct SaleGradeCell: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: DeviceProcessingItem

    var body: some View {
      Picker("Grade", selection: $item.gradeRawValue) {
        ForEach(SaleGrade.allCases, id: \.self) { grade in
          Text(grade.rawValue).tag(grade.rawValue as String?)
        }
      }
      .labelsHidden()
      .disabled(item.state == .processing || item.state == .completed)
      .onChange(of: item.gradeRawValue) { _, _ in
        if item.state == .failed {
          item.prepareForRetry()
        }
        try? modelContext.save()
      }
    }
  }

  private struct SaleNotesCell: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: DeviceProcessingItem

    var body: some View {
      TextField("Condition notes", text: $item.conditionNotes)
        .disabled(item.state == .processing || item.state == .completed)
        .onSubmit {
          if item.state == .failed {
            item.prepareForRetry()
          }
          item.conditionNotes = item.conditionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
          try? modelContext.save()
        }
    }
  }
#endif
