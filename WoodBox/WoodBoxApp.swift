//
//  WoodBoxApp.swift
//  WoodBox
//
//  Created by Alexander Hyde on 8/2/2026.
//

import SwiftData
import SwiftUI

@main
struct WoodBoxApp: App {
  private let modelTypes: [any PersistentModel.Type] = {
    var modelTypes: [any PersistentModel.Type] = [
      Device.self,
      MDMRecord.self,
      SnipeItStatus.self,
      SnipeItUser.self,
    ]

    #if os(iOS)
      modelTypes.append(BulkScanHistoryItem.self)
    #endif

    return modelTypes
  }()

  private let container: ModelContainer
  private let modelData: ModelData

  // MARK: - Init

  init() {
    let schema = Schema(modelTypes)
    container = try! ModelContainer(for: schema)
    modelData = ModelData(modelContext: ModelContext(container))
  }

  // MARK: - Body

  var body: some Scene {
    WindowGroup {
      ToolsSplitView()
        .environment(modelData)
    }
    .modelContainer(container)

    #if os(macOS)
      Settings {
        SettingsView()
          .environment(modelData)
      }
      .modelContainer(container)
    #endif
  }
}
