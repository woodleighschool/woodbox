import SwiftUI

struct SnipeStatusPicker: View {
  @Environment(ModelData.self) private var modelData

  let title: String
  @Binding var selection: Int?
  var includesNoChange = true

  init(_ title: String, selection: Binding<Int?>, includesNoChange: Bool = true) {
    self.title = title
    _selection = selection
    self.includesNoChange = includesNoChange
  }

  var body: some View {
    let statuses = modelData.snipeReferenceData.statuses
    Picker(title, selection: $selection) {
      Text(statuses.isEmpty ? "Statuses Unavailable" : (includesNoChange ? "No Change" : "Choose Status")).tag(nil as Int?)

      ForEach(statuses) { status in
        Text(status.name).tag(Optional(status.id))
      }
    }
    .disabled(statuses.isEmpty)
  }
}
