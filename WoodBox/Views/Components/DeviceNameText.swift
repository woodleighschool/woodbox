import SwiftUI

struct DeviceTitle: View {
  let model: String
  let name: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(model.nilIfEmpty ?? "Model not reported")
        .font(.headline)
        .lineLimit(1)
      DeviceNameText(name: name)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

struct DeviceNameText: View {
  let name: String?

  var body: some View {
    if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
      Text(name)
    }
  }
}
