import SwiftData
import SwiftUI

// MARK: - Public API

extension View {
  func deviceSearch(selection: DeviceSelectionState, isEnabled: Bool = true) -> some View {
    modifier(DeviceSearch(selection: selection, isEnabled: isEnabled))
  }
}

// MARK: - Modifier

private struct DeviceSearch: ViewModifier {
  @Bindable var selection: DeviceSelectionState
  let isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      DeviceSearchBody(content: content, selection: selection)
    } else {
      content
    }
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
              HStack(alignment: .center, spacing: 10) {
                Image(systemName: device.symbolName)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 24, height: 24)
                  .symbolEffect(.bounce, value: selection.selectedDevice?.serial == device.serial)
                VStack(alignment: .leading, spacing: 2) {
                  DeviceNameText(name: device.name)
                  HStack(spacing: 4) {
                    Image(systemName: "barcode")
                    Text(device.assetTag)
                    Image(systemName: "number")
                    Text(device.serial)
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
              }
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
        ToolbarItem(placement: .topBarTrailing) {
          Button("Scan Device", systemImage: "camera.viewfinder") {
            isScanningDevice = true
          }
        }
      }
    #endif
  }

  private var filteredDevices: [Device] {
    modelContext.searchDevices(matching: selection.query)
  }
}
