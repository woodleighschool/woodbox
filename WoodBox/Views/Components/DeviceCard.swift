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
    HStack(alignment: .center, spacing: 12) {
      icon
      content
      Spacer(minLength: 8)
      accessory()
      clearButton
    }
    .contentShape(Rectangle())
    .deviceDetails(device)
  }

  // MARK: - View Builders

  private var icon: some View {
    let symbol = device?.symbolName ?? "macbook.and.iphone"
    return Image(systemName: symbol)
      .font(.title3.weight(.semibold))
      .frame(width: 40, height: 40)
      .foregroundStyle(device != nil ? Color.accentColor : Color.secondary)
      .symbolRenderingMode(.hierarchical)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let device {
        DeviceNameText(name: device.name)
          .font(.headline)
          .lineLimit(1)
        Text(device.model)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        identifiersRow(device)
      } else {
        Text("No Device Selected")
          .font(.headline)
          .foregroundStyle(.secondary)
        Text("Search or scan to begin")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func identifiersRow(_ device: Device) -> some View {
    HStack(spacing: 8) {
      DeviceIdentifiersRow(assetTag: device.assetTag, serial: device.serial)
      #if os(macOS)
        if let storage = device.storage.nilIfEmpty {
          Label(storage, systemImage: "internaldrive")
        }
        if let ram = device.ram.nilIfEmpty {
          Label(ram, systemImage: "memorychip")
        }
        if let expires = device.warrantyExpires {
          Label(
            expires.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)),
            systemImage: "shield"
          )
        }
      #endif
    }
    .font(.caption.monospacedDigit())
    .foregroundStyle(.secondary)
    .lineLimit(1)
  }

  @ViewBuilder
  private var clearButton: some View {
    if let onClear, device != nil {
      Button(action: onClear) {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .symbolRenderingMode(.hierarchical)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
    }
  }
}

struct DeviceIdentityLabel<Details: View>: View {
  let device: Device?
  let name: String?
  let model: String
  let assetTag: String
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
        if let name = name.nilIfEmpty {
          Text(name)
            .font(.headline)
            .lineLimit(1)

          Text(model)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else {
          Text(model)
            .font(.headline)
            .lineLimit(1)
        }

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
  init(device: Device?, name: String?, model: String, assetTag: String, serial: String) {
    self.init(device: device, name: name, model: model, assetTag: assetTag, serial: serial) {
      EmptyView()
    }
  }
}

struct DeviceIdentifiersRow: View {
  let assetTag: String
  let serial: String

  var body: some View {
    HStack(spacing: 8) {
      Label(assetTag, systemImage: "barcode")
      Label(serial, systemImage: "number")
    }
    .lineLimit(1)
  }
}

// MARK: - DeviceDetailSheet

#if os(iOS)
  private struct DeviceDetailsPresenter: ViewModifier {
    let device: Device?

    @State private var isPresented = false

    func body(content: Content) -> some View {
      content
        .highPriorityGesture(
          LongPressGesture(minimumDuration: 0.35)
            .onEnded { _ in
              guard device != nil else { return }
              isPresented = true
            }
        )
        .sheet(isPresented: $isPresented) {
          if let device {
            DeviceDetailSheet(device: device)
              .presentationDetents([.medium, .large])
          }
        }
    }
  }

  private struct DeviceDetailSheet: View {
    // MARK: - Properties

    let device: Device

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

          Section("Assignment & MDM") {
            if let user = device.assignedUserName.nilIfEmpty {
              LabeledRow("Assigned To", value: user, systemImage: "person")
            }
            if let email = device.assignedUserEmail.nilIfEmpty {
              LabeledRow("Email", value: email, systemImage: "envelope")
            }
            if !device.mdmProviderNames.isEmpty {
              LabeledRow(
                "MDM",
                value: device.mdmProviderNames.joined(separator: ", "),
                systemImage: "iphone.and.arrow.forward"
              )
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
        .navigationBarTitleDisplayMode(.inline)
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
#endif

private extension View {
  @ViewBuilder
  func deviceDetails(_ device: Device?) -> some View {
    #if os(iOS)
      modifier(DeviceDetailsPresenter(device: device))
    #else
      self
    #endif
  }
}
