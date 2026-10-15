import SwiftUI

// MARK: - DeviceSummaryItem

struct DeviceSummaryItem<Accessory: View>: View {
  // MARK: - Properties

  let device: Device?
  var onClear: (() -> Void)?
  @ViewBuilder var accessory: () -> Accessory

  // MARK: - Initialization

  init(
    device: Device?,
    onClear: (() -> Void)? = nil,
    @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
  ) {
    self.device = device
    self.onClear = onClear
    self.accessory = accessory
  }

  // MARK: - Body

  var body: some View {
    HStack(spacing: 12) {
      if let device {
        DeviceIdentityLabel(
          device: device,
          name: device.name,
          model: device.model,
          assetTag: device.assetTag,
          serial: device.serial
        )
      } else {
        ContentUnavailableView(
          "No Device Selected",
          systemImage: "barcode.viewfinder",
          description: Text("Search or scan to begin.")
        )
      }
      accessory()
      if let onClear, device != nil {
        Button("Clear Device", systemImage: "xmark.circle.fill", action: onClear)
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .font(.title3)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct DeviceIdentityLabel<Details: View>: View {
  let device: Device?
  let name: String?
  let model: String
  let assetTag: String?
  let serial: String
  @ViewBuilder let details: Details

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: Device.symbolName(for: model))
        .font(.title3.weight(.semibold))
        .frame(width: 40, height: 40)
        .foregroundStyle(.tint)
        .symbolRenderingMode(.hierarchical)

      VStack(alignment: .leading, spacing: 3) {
        DeviceTitle(model: model, name: name)

        DeviceIdentifiersRow(assetTag: assetTag, serial: serial)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)

        details
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .contentShape(Rectangle())
    .deviceDetails(device)
  }
}

extension DeviceIdentityLabel where Details == EmptyView {
  init(device: Device?, name: String?, model: String, assetTag: String?, serial: String) {
    self.init(device: device, name: name, model: model, assetTag: assetTag, serial: serial) {
      EmptyView()
    }
  }
}

struct DeviceIdentifiersRow: View {
  let assetTag: String?
  let serial: String

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        identifiers
      }
      .fixedSize(horizontal: true, vertical: false)

      VStack(alignment: .leading, spacing: 2) {
        identifiers
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var identifiers: some View {
    if let assetTag = assetTag.nilIfEmpty {
      Text("\(Image(systemName: "barcode")) \(assetTag)")
    }
    Text("\(Image(systemName: "number")) \(serial)")
  }
}

// MARK: - DeviceDetailSheet

private struct DeviceDetailsPresenter: ViewModifier {
  let device: Device?

  @State private var isPresented = false

  func body(content: Content) -> some View {
    content
      .contextMenu {
        if device != nil {
          Button("Device Details", systemImage: "info.circle") { isPresented = true }
        }
      }
      .sheet(isPresented: $isPresented) {
        if let device {
          DeviceDetailSheet(device: device)
          #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
          #else
            .frame(minWidth: 360, idealWidth: 480, minHeight: 380, idealHeight: 560)
          #endif
        }
      }
  }
}

private struct DeviceDetailSheet: View {
  // MARK: - Properties

  let device: Device
  #if os(macOS)
    @Environment(\.dismiss) private var dismiss
  #endif

  // MARK: - Body

  var body: some View {
    NavigationStack {
      List {
        Section("Device") {
          LabeledRow("Serial", value: device.serial, systemImage: "number")
          LabeledRow("Asset Tag", value: device.assetTag, systemImage: "barcode")

          if let model = device.model.nilIfEmpty {
            LabeledRow("Model", value: model, systemImage: "laptopcomputer")
          }
          if let storage = device.storage.nilIfEmpty {
            LabeledRow("Storage", value: storage, systemImage: "internaldrive")
          }
          if let ram = device.ram.nilIfEmpty {
            LabeledRow("Memory", value: ram, systemImage: "memorychip")
          }
          if let expires = device.warrantyExpires {
            LabeledRow(
              "Warranty",
              value: expires.formatted(
                .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)
              ),
              systemImage: "shield"
            )
          }
        }

        Section("Details") {
          if let name = device.name.nilIfEmpty {
            LabeledRow("Name", value: name, systemImage: "tag")
          }
          if let category = device.category.nilIfEmpty {
            LabeledRow("Category", value: category, systemImage: "square.3.layers.3d")
          }
          if let status = device.status.nilIfEmpty {
            LabeledRow("Status", value: status, systemImage: "checkmark.seal")
          }
          if let snipeId = device.snipeItId {
            LabeledRow("Snipe-IT ID", value: String(snipeId), systemImage: "shippingbox")
          }
        }

        if device.assignedUserName.nilIfEmpty != nil || device.assignedUserEmail.nilIfEmpty != nil {
          Section("Assignment") {
            if let user = device.assignedUserName.nilIfEmpty {
              LabeledRow("Assigned To", value: user, systemImage: "person")
            }
            if let email = device.assignedUserEmail.nilIfEmpty {
              LabeledRow("Email", value: email, systemImage: "envelope")
            }
          }
        }

        if let notes = device.notes.nilIfEmpty {
          Section("Notes") {
            Text(notes)
              .font(.body)
          }
        }
      }
      .textSelection(.enabled)
      .navigationTitle("Device Details")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      #if os(macOS)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      #endif
    }
  }
}

private struct LabeledRow: View {
  let title: String
  let value: String
  let systemImage: String

  init(_ title: String, value: String, systemImage: String) {
    self.title = title
    self.value = value
    self.systemImage = systemImage
  }

  var body: some View {
    Label {
      HStack(spacing: 12) {
        Text(title)
          .foregroundStyle(.secondary)

        Spacer(minLength: 8)

        Text(value)
          .multilineTextAlignment(.trailing)
          .foregroundStyle(.primary)
      }
    } icon: {
      Image(systemName: systemImage)
    }
  }
}

private extension View {
  func deviceDetails(_ device: Device?) -> some View {
    modifier(DeviceDetailsPresenter(device: device))
  }
}
