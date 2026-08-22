import SwiftUI

struct DeviceNameText: View {
  let name: String?

  var body: some View {
    if let name, !name.isEmpty {
      Text(name)
    } else {
      Text("Unknown")
        .italic()
        .foregroundStyle(.secondary)
    }
  }
}
