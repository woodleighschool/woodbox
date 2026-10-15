import SwiftData
import SwiftUI

@main
struct WoodBoxApp: App {
  private let modelTypes: [any PersistentModel.Type] = [Device.self, DeviceProcessingItem.self]

  private let container: ModelContainer
  private let modelData: ModelData

  // MARK: - Init

  init() {
    let schema = Schema(modelTypes)
    let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || NSClassFromString("XCTestCase") != nil
    container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: isTesting))
    let settings = isTesting
      ? AppSettings(defaults: UserDefaults(suiteName: "WoodBox.Tests")!, usesKeychain: false)
      : .shared
    modelData = ModelData(modelContext: ModelContext(container), settings: settings)
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
