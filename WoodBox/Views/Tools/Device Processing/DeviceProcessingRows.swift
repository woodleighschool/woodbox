import SwiftData
import SwiftUI

#if os(iOS)
  struct DeviceProcessingQueueRow: View {
    @Environment(\.modelContext) private var modelContext

    let item: DeviceProcessingItem

    var body: some View {
      Group {
        if item.profile.requiresCondition {
          NavigationLink {
            SaleConditionEditor(item: item, device: device)
          } label: {
            DeviceProcessingItemRow(item: item, device: device)
          }
        } else {
          DeviceProcessingItemRow(item: item, device: device)
        }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button("Remove", systemImage: "trash", role: .destructive, action: remove)
      }
    }

    private func remove() {
      modelContext.delete(item)
      try? modelContext.save()
    }

    private var device: Device? {
      modelContext.fetchDevice(serial: item.serial)
    }
  }

  struct DeviceProcessingItemRow: View {
    let item: DeviceProcessingItem
    let device: Device?

    var body: some View {
      HStack(spacing: 8) {
        DeviceIdentityLabel(
          device: device,
          name: item.deviceName,
          model: item.deviceModel,
          assetTag: item.assetTag,
          serial: item.serial
        ) {
          if let notes = item.conditionNotes.nilIfEmpty {
            Text(notes)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        if let grade = item.grade {
          Image(systemName: grade.symbolName)
            .font(.title3)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(grade.color)
        }
      }
    }
  }

  private extension SaleGrade {
    var symbolName: String {
      "\(rawValue.lowercased()).circle.fill"
    }

    var color: Color {
      switch self {
      case .a: .green
      case .b: .blue
      case .c: .orange
      case .d: .red
      }
    }
  }
#endif

struct SaleConditionForm: View {
  let device: Device?
  let name: String?
  let assetTag: String
  let serial: String
  let model: String

  @Binding var grade: SaleGrade?
  @Binding var notes: String

  var body: some View {
    Form {
      Section {
        DeviceIdentityLabel(
          device: device,
          name: name,
          model: model,
          assetTag: assetTag,
          serial: serial
        )
      }

      Section("Condition") {
        Picker("Grade", selection: $grade) {
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
        .lineLimit(2 ... 4)
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
    let device: Device?

    @State private var grade: SaleGrade?
    @State private var notes: String

    init(item: DeviceProcessingItem, device: Device?) {
      self.item = item
      self.device = device
      _grade = State(initialValue: item.grade)
      _notes = State(initialValue: item.conditionNotes)
    }

    private var canSave: Bool {
      grade != nil
    }

    var body: some View {
      SaleConditionForm(
        device: device,
        name: item.deviceName,
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
          DeviceTitle(model: item.deviceModel, name: item.deviceName)
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

        TableColumn("") { item in
          Button("Remove", systemImage: "trash", role: .destructive) {
            onRemove(item)
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
        }
        .width(32)
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
      .onChange(of: item.gradeRawValue) { _, _ in
        try? modelContext.save()
      }
    }
  }

  private struct SaleNotesCell: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: DeviceProcessingItem

    var body: some View {
      TextField("Condition notes", text: $item.conditionNotes)
        .onSubmit {
          item.conditionNotes = item.conditionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
          try? modelContext.save()
        }
    }
  }
#endif
