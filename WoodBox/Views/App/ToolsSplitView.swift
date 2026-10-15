import SwiftData
import SwiftUI

struct ToolsSplitView: View {
  // MARK: - Properties

  @Environment(ModelData.self) private var modelData
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
      .enrollment,
    ]
  }

  // MARK: - Body

  var body: some View {
    #if os(iOS)
      iOSToolsView
    #else
      macOSToolsView
    #endif
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
        .assetRefreshable()
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
        NavigationStack {
          SettingsView()
        }
        .presentationDragIndicator(.visible)
      }
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

    case .enrollment:
      EnrollmentPolicyView()
    }
  }
}
