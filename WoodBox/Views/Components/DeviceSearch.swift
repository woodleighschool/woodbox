import SwiftData
import SwiftUI

struct DeviceSearchResultLabel: View {
  let device: Device

  var body: some View {
    DeviceIdentityLabel(
      device: nil,
      name: device.name,
      model: device.model,
      assetTag: device.assetTag,
      serial: device.serial
    )
  }
}

// MARK: - Public API

extension View {
  func deviceSearch(selection: DeviceSelectionState) -> some View {
    modifier(DeviceSearch(selection: selection))
  }
}

// MARK: - Modifier

private struct DeviceSearch: ViewModifier {
  @Bindable var selection: DeviceSelectionState

  func body(content: Content) -> some View {
    DeviceSearchBody(content: content, selection: selection)
  }
}

// MARK: - Body

private struct DeviceSearchBody<Content: View>: View {
  let content: Content
  @Bindable var selection: DeviceSelectionState

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismissSearch) private var dismissSearch
  @State private var isSearchPresented = false

  #if os(iOS)
    @State private var isScanningDevice = false
  #endif

  var body: some View {
    content
      .searchable(
        text: $selection.query,
        isPresented: $isSearchPresented,
        prompt: "Pick a Device..."
      )
      .searchSuggestions {
        if !selection.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          ForEach(filteredDevices) { device in
            Button {
              selection.select(device)
              isSearchPresented = false
              dismissSearch()
            } label: {
              DeviceSearchResultLabel(device: device)
            }
          }
        }
      }
      .onSubmit(of: .search) {
        guard let firstMatch = filteredDevices.first else { return }
        selection.select(firstMatch)
        isSearchPresented = false
        dismissSearch()
      }
    #if os(iOS)
      .sheet(isPresented: $isScanningDevice) {
        DeviceScannerSheet(selection: selection)
          .presentationDetents([.medium])
          .presentationDragIndicator(.visible)
      }
      .toolbar {
        ScanSearchToolbar {
          isScanningDevice = true
        }
      }
    #endif
  }

  private var filteredDevices: [Device] {
    modelContext.searchDevices(matching: selection.query)
  }
}
