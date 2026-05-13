//
//  SnipeStatusPicker.swift
//  WoodBox
//
//  Created by Alexander Hyde on 13/5/2026.
//

import SwiftData
import SwiftUI

struct SnipeStatusPicker: View {
  @Query(sort: [SortDescriptor(\SnipeItStatus.name)])
  private var statuses: [SnipeItStatus]

  let title: String
  @Binding var selection: Int?
  var includesNoChange = true

  init(_ title: String, selection: Binding<Int?>, includesNoChange: Bool = true) {
    self.title = title
    _selection = selection
    self.includesNoChange = includesNoChange
  }

  var body: some View {
    Picker(title, selection: $selection) {
      if includesNoChange {
        Text("No change").tag(nil as Int?)
      }

      ForEach(statuses) { status in
        Text(status.name).tag(Optional(status.snipeItId))
      }
    }
    .disabled(statuses.isEmpty)
  }
}
