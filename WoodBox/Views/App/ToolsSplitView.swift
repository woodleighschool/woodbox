import SwiftData
import SwiftUI

struct ToolsSplitView: View {
  // MARK: - Properties

  @Environment(ModelData.self) private var modelData
  @Environment(\.scenePhase) private var scenePhase
  #if os(iOS)
    @State private var isSettingsSheetPresented = false
  #endif

  private var workflowTabs: [AppTab] {
    [
      .repairIntake,
      .restock,
      .sale,
    ]
  }

  private var utilityTabs: [AppTab] {
    [
      .deviceDeduplication,
    ]
  }

  // MARK: - Body

  var body: some View {
    Group {
      #if os(iOS)
        iOSToolsView
      #else
        macOSToolsView
      #endif
    }
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      await modelData.cacheManager.syncIfNeeded()
    }
  }

  #if os(iOS)
    private var iOSToolsView: some View {
      NavigationStack {
        List {
          Section("Workflows") {
            ForEach(workflowTabs) { tab in
              NavigationLink(value: tab) {
                Label(tab.title, systemImage: tab.symbol)
              }
            }
          }

          Section("Utilities") {
            ForEach(utilityTabs) { tab in
              NavigationLink(value: tab) {
                Label(tab.title, systemImage: tab.symbol)
              }
            }
          }
        }
        .navigationTitle("WoodBox")
        .refreshable {
          await refreshCache()
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button("Settings", systemImage: "gearshape") {
              isSettingsSheetPresented = true
            }
          }
        }
        .navigationDestination(for: AppTab.self) { tab in
          toolContent(for: tab)
            .navigationTitle(tab.title)
        }
      }
      .sheet(isPresented: $isSettingsSheetPresented) {
        settingsSheet
      }
    }

    private func refreshCache() async {
      await modelData.cacheManager.sync()
    }
  #else
    private var navigationTabs: [AppTab] {
      workflowTabs + utilityTabs
    }

    private var macOSToolsView: some View {
      @Bindable var modelData = modelData

      let selectedTab = Binding<AppTab?>(
        get: {
          navigationTabs.contains(modelData.selectedTab) ? modelData.selectedTab : nil
        },
        set: { newValue in
          if let newValue {
            modelData.selectedTab = newValue
          }
        }
      )

      return NavigationSplitView {
        List(selection: selectedTab) {
          Section("Workflows") {
            ForEach(workflowTabs) { tab in
              Label(tab.title, systemImage: tab.symbol)
                .tag(tab)
            }
          }

          Section("Utilities") {
            ForEach(utilityTabs) { tab in
              Label(tab.title, systemImage: tab.symbol)
                .tag(tab)
            }
          }
        }
        .navigationTitle("WoodBox")
      } detail: {
        NavigationStack {
          toolContent(for: modelData.selectedTab)
            .navigationTitle(modelData.selectedTab.title)
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          CacheRefreshButton()
        }
      }
    }
  #endif

  @ViewBuilder
  private func toolContent(for tab: AppTab) -> some View {
    switch tab {
    case .repairIntake:
      RepairIntakeView(deviceSelection: modelData.deviceSelection)

    case .restock:
      DeviceProcessingView(profile: .restock)

    case .sale:
      DeviceProcessingView(profile: .sale)

    case .deviceDeduplication:
      DeviceDeduplicationView()
    }
  }

  #if os(iOS)
    private var settingsSheet: some View {
      NavigationStack {
        SettingsView()
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                isSettingsSheetPresented = false
              }
            }
          }
      }
    }
  #endif
}
