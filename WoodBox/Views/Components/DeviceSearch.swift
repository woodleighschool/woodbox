import SwiftData
import SwiftUI

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
      }
      .toolbar {
        // I do want this next to the search field, does not seem achievable...?
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isScanningDevice = true
          } label: {
            Image(systemName: "camera.viewfinder")
          }
        }
      }
    #endif
  }

  private var filteredDevices: [Device] {
    let q = selection.query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }

    var descriptor = FetchDescriptor<Device>(
      predicate: #Predicate { device in
        device.serial.localizedStandardContains(q)
          || device.assetTag.localizedStandardContains(q)
          || device.assignedUserEmail?.localizedStandardContains(q) == true
      },
      sortBy: [SortDescriptor(\Device.name)]
    )
    descriptor.fetchLimit = 25
    return (try? modelContext.fetch(descriptor)) ?? []
  }
}
