import SwiftData
import SwiftUI

struct DeviceProcessingView: View {
  private enum PresentedSheet: Identifiable {
    case capture(DeviceProcessingCapture)
    case application(DeviceProcessingApplication)

    var id: UUID {
      switch self {
      case let .capture(capture): capture.id
      case let .application(application): application.id
      }
    }
  }

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  @Query(sort: [SortDescriptor(\DeviceProcessingItem.addedAt)])
  private var allItems: [DeviceProcessingItem]

  @Query(sort: [SortDescriptor(\SnipeItStatus.name)])
  private var statuses: [SnipeItStatus]

  let profile: DeviceProcessingProfile

  @State private var selectedStatusId: Int?
  @State private var searchQuery = ""
  @State private var scannerInput = ""
  @State private var showClearConfirmation = false
  @State private var alertItem: AlertItem?
  @State private var presentedSheet: PresentedSheet?

  #if os(macOS)
    @FocusState private var scannerInputFocused: Bool
  #endif

  private var items: [DeviceProcessingItem] {
    allItems.filter { $0.profile == profile }
  }

  private var targetStatus: SnipeItStatus? {
    guard let selectedStatusId else { return nil }
    return statuses.first { $0.snipeItId == selectedStatusId }
  }

  private var searchResults: [Device] {
    modelContext.searchDevices(matching: searchQuery)
  }

  private var isApplyDisabled: Bool {
    targetStatus == nil
      || items.isEmpty
  }

  var body: some View {
    platformContent
      .searchable(text: $searchQuery, prompt: "Add a Device")
      .searchSuggestions {
        ForEach(searchResults) { device in
          Button {
            beginCapture(for: device)
            searchQuery = ""
          } label: {
            DeviceSearchResultLabel(device: device)
          }
        }
      }
      .onSubmit(of: .search) {
        guard let device = searchResults.first else { return }
        beginCapture(for: device)
        searchQuery = ""
      }
      .confirmationDialog(
        "Clear \(profile.title) Queue?",
        isPresented: $showClearConfirmation,
        titleVisibility: .visible
      ) {
        Button("Clear Queue", role: .destructive, action: clearItems)
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This removes the local working list. It does not change any external system.")
      }
      .alert(item: $alertItem) { item in
        Alert(
          title: Text(item.title),
          message: Text(item.message),
          dismissButton: .default(Text("OK"))
        )
      }
      .sheet(item: $presentedSheet) { sheet in
        switch sheet {
        case let .capture(capture):
          #if os(iOS)
            DeviceProcessingCaptureView(
              profile: profile,
              start: capture.start,
              candidate: resolveCandidate,
              commit: commit
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
          #else
            DeviceProcessingCaptureView(
              start: capture.start,
              commit: commit
            )
          #endif

        case let .application(application):
          DeviceProcessingApplyView(items: items, application: application)
          #if os(iOS)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
          #endif
        }
      }
      .onChange(of: statuses.map(\.snipeItId), initial: true) { _, _ in
        restoreStatusSelection()
      }
      .onChange(of: selectedStatusId) { _, newValue in
        modelData.settings.setLastTargetStatusId(newValue, for: profile)
      }
  }

  @ViewBuilder
  private var platformContent: some View {
    #if os(iOS)
      iOSContent
    #else
      macOSContent
    #endif
  }

  #if os(iOS)
    private var iOSContent: some View {
      List {
        destinationSection

        if items.isEmpty {
          ContentUnavailableView {
            Label("No Devices", systemImage: "barcode.viewfinder")
          } description: {
            Text("Use Search or Scan to build the \(profile.title.lowercased()) queue.")
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        } else {
          Section("Devices") {
            ForEach(items) { item in
              DeviceProcessingQueueRow(item: item)
            }
          }
        }
      }
      .navigationTitle(profile.title)
      .refreshable {
        await modelData.cacheManager.sync()
      }
      .scrollDismissesKeyboard(.interactively)
      .toolbar { iOSToolbar }
    }

    private var destinationSection: some View {
      Section {
        SnipeStatusPicker("Apply Status", selection: $selectedStatusId, includesNoChange: false)
      } header: {
        Text("Destination")
      }
    }

    @ToolbarContentBuilder
    private var iOSToolbar: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Scan", systemImage: "camera.viewfinder") {
          presentCapture(start: .scanner)
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          if let saleCSV {
            ShareLink(item: saleCSV, preview: SharePreview("Sale Devices")) {
              Label("Export CSV", systemImage: "square.and.arrow.up")
            }
          }

          Button("Clear Queue", systemImage: "trash", role: .destructive) {
            showClearConfirmation = true
          }
          .disabled(items.isEmpty)
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }

      ToolbarItem(placement: .confirmationAction) {
        Button("Apply", action: presentApplication)
          .disabled(isApplyDisabled)
          .buttonStyle(.borderedProminent)
      }
    }

  #else
    private var macOSContent: some View {
      VStack(spacing: 0) {
        macOSControls

        Divider()

        if items.isEmpty {
          ContentUnavailableView(
            "No Devices",
            systemImage: "barcode.viewfinder",
            description: Text("Scan an asset tag or serial number to begin.")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          DeviceProcessingTable(items: items, profile: profile, onRemove: remove)
        }
      }
      .toolbar { macOSToolbar }
      .onAppear { scannerInputFocused = true }
    }

    private var macOSControls: some View {
      HStack(spacing: 12) {
        TextField("Scan asset tag or serial number", text: $scannerInput)
          .textFieldStyle(.roundedBorder)
          .focused($scannerInputFocused)
          .onSubmit(addScannerInput)

        Button("Add", systemImage: "plus", action: addScannerInput)
          .disabled(scannerInput.nilIfEmpty == nil)

        Divider().frame(height: 20)

        SnipeStatusPicker("Apply Status", selection: $selectedStatusId, includesNoChange: false)
          .frame(minWidth: 220)
      }
      .padding(12)
    }

    @ToolbarContentBuilder
    private var macOSToolbar: some ToolbarContent {
      ToolbarItemGroup(placement: .primaryAction) {
        if let saleCSV {
          ShareLink(item: saleCSV, preview: SharePreview("Sale Devices")) {
            Label("Export CSV", systemImage: "square.and.arrow.up")
          }
          .disabled(items.isEmpty)
        }

        Button("Clear Queue", systemImage: "trash", role: .destructive) {
          showClearConfirmation = true
        }
        .disabled(items.isEmpty)

        Button("Apply", systemImage: "checkmark", action: presentApplication)
          .disabled(isApplyDisabled)
          .keyboardShortcut(.return, modifiers: [.command])
      }
    }
  #endif

  private func restoreStatusSelection() {
    guard !statuses.isEmpty else { return }
    let remembered = modelData.settings.lastTargetStatusId(for: profile)
    selectedStatusId = statuses.contains { $0.snipeItId == remembered } ? remembered : nil
  }

  private func validate(_ device: Device) throws {
    if let existing = allItems.first(where: { $0.serial == device.serial }) {
      throw DeviceProcessingError.alreadyQueued(existing.profile)
    }
  }

  private func commit(_ draft: DeviceProcessingDraft) throws {
    try validate(draft.device)
    let item = DeviceProcessingItem(draft)
    modelContext.insert(item)
    do {
      try modelContext.save()
    } catch {
      modelContext.delete(item)
      throw error
    }
  }

  private func beginCapture(for device: Device) {
    do {
      switch profile {
      case .restock:
        try commit(.restock(device))
      case .sale:
        try validate(device)
        presentCapture(start: .condition(device))
      }
    } catch {
      present(error)
    }
  }

  #if os(iOS)
    private func resolveCandidate(_ value: String, _ scanType: ScanType) throws -> Device {
      guard let device = modelContext.fetchDevice(matching: value, scanType: scanType) else {
        throw DeviceProcessingError.deviceNotFound("\(scanType.label) “\(value)”")
      }
      try validate(device)
      return device
    }
  #endif

  private func addScannerInput() {
    guard let value = scannerInput.nilIfEmpty else { return }
    defer {
      scannerInput = ""
      #if os(macOS)
        scannerInputFocused = true
      #endif
    }

    guard let device = modelContext.fetchDevice(matchingIdentifier: value) else {
      present(DeviceProcessingError.deviceNotFound("asset tag or serial number “\(value)”"))
      return
    }
    beginCapture(for: device)
  }

  private func present(_ error: any Error) {
    alertItem = AlertItem(title: "Unable to Add Device", message: error.localizedDescription)
  }

  private func remove(_ item: DeviceProcessingItem) {
    modelContext.delete(item)
    try? modelContext.save()
  }

  private func clearItems() {
    items.forEach(modelContext.delete)
    try? modelContext.save()
    selectedStatusId = modelData.settings.lastTargetStatusId(for: profile)
  }

  private func presentCapture(start: DeviceProcessingCapture.Start) {
    presentedSheet = .capture(DeviceProcessingCapture(start: start))
  }

  private func presentApplication() {
    guard let targetStatus else { return }
    presentedSheet = .application(
      DeviceProcessingApplication(
        statusId: targetStatus.snipeItId,
        statusName: targetStatus.name
      )
    )
  }

  private var saleCSV: SaleCSV? {
    guard profile == .sale, !items.isEmpty else { return nil }
    return SaleCSV(items: items, statusName: targetStatus?.name)
  }
}
