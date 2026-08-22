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
      .returnCheckIn,
      .salePreparation,
    ]
  }

  private var utilityTabs: [AppTab] {
    var tabs: [AppTab] = [
      .deviceDeduplication,
    ]

    #if os(iOS)
      tabs.append(.bulkScanner)
    #endif

    return tabs
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
        .navigationTitle("Tools")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            SettingsButton {
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
        .navigationTitle("Tools")
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

    case .returnCheckIn:
      ReturnCheckInView(deviceSelection: modelData.deviceSelection)

    case .salePreparation:
      SalePreparationView(deviceSelection: modelData.deviceSelection)

    case .deviceDeduplication:
      DeviceDeduplicationView()

    #if os(iOS)
      case .bulkScanner:
        BulkScannerView()
    #endif
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

#if os(iOS)
  private struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Image(systemName: "gearshape")
          .font(.title2)
          .symbolRenderingMode(.hierarchical)
      }
      .accessibilityLabel("Open settings")
      .buttonStyle(.plain)
    }
  }
#endif
