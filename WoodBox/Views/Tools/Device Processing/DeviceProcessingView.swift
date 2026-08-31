import SwiftData
import SwiftUI

struct DeviceProcessingView: View {
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
  @State private var isProcessing = false
  @State private var showApplyConfirmation = false
  @State private var showClearConfirmation = false
  @State private var alertItem: AlertItem?
  @State private var capture: DeviceProcessingCapture?

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

  private var pendingItems: [DeviceProcessingItem] {
    items.filter { $0.state != .completed && $0.state != .processing }
  }

  private var searchResults: [Device] {
    modelContext.searchDevices(matching: searchQuery)
  }

  private var isApplyDisabled: Bool {
    targetStatus == nil
      || pendingItems.isEmpty
      || isProcessing
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
        "Process \(pendingItems.count) \(pendingItems.count == 1 ? "Device" : "Devices")?",
        isPresented: $showApplyConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete from MDM and Apply Status", role: .destructive) {
          Task { await processPendingItems() }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(confirmationMessage)
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
      .sheet(item: $capture) { capture in
        #if os(iOS)
          DeviceProcessingCaptureView(
            profile: profile,
            start: capture.start,
            candidate: resolveCandidate,
            commit: commit
          )
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
        #else
          DeviceProcessingCaptureView(
            start: capture.start,
            commit: commit
          )
        #endif
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
            Text("Search or scan to build the \(profile.title.lowercased()) queue.")
          } actions: {
            Button {
              capture = DeviceProcessingCapture(start: .scanner)
            } label: {
              Label("Start Scanning", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        } else {
          Section("Devices") {
            ForEach(items) { item in
              if profile.requiresCondition {
                NavigationLink {
                  SaleConditionEditor(item: item)
                } label: {
                  DeviceProcessingItemRow(item: item)
                }
                .disabled(item.state == .processing || item.state == .completed)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                  removeButton(for: item)
                }
              } else {
                DeviceProcessingItemRow(item: item)
                  .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    removeButton(for: item)
                  }
              }
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
          .disabled(isProcessing)
      } header: {
        Text("Destination")
      }
    }

    @ToolbarContentBuilder
    private var iOSToolbar: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Scan", systemImage: "camera.viewfinder") {
          capture = DeviceProcessingCapture(start: .scanner)
        }
        .disabled(isProcessing)
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
          .disabled(items.isEmpty || isProcessing)
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }

      ToolbarItem(placement: .confirmationAction) {
        if isProcessing {
          ProgressView().controlSize(.small)
        } else {
          Button("Apply") {
            showApplyConfirmation = true
          }
          .disabled(isApplyDisabled)
          .buttonStyle(.borderedProminent)
        }
      }
    }

    private func removeButton(for item: DeviceProcessingItem) -> some View {
      Button("Remove", systemImage: "trash", role: .destructive) {
        remove(item)
      }
      .disabled(item.state == .processing)
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
          .disabled(scannerInput.nilIfEmpty == nil || isProcessing)

        Divider().frame(height: 20)

        SnipeStatusPicker("Apply Status", selection: $selectedStatusId, includesNoChange: false)
          .frame(minWidth: 220)
          .disabled(isProcessing)
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
        .disabled(items.isEmpty || isProcessing)

        if isProcessing {
          ProgressView().controlSize(.small)
        } else {
          Button("Apply", systemImage: "checkmark") {
            showApplyConfirmation = true
          }
          .disabled(isApplyDisabled)
          .keyboardShortcut(.return, modifiers: [.command])
        }
      }
    }
  #endif

  private var confirmationMessage: String {
    guard let targetStatus else { return "Choose a Snipe-IT status first." }

    let providers = pendingItems
      .compactMap(device(for:))
      .flatMap(\.mdmProviderNames)
    let providerNames = Array(Set(providers)).sorted()
    let deletionDescription = providerNames.isEmpty
      ? "No cached MDM records will be deleted."
      : "The devices will be deleted from \(providerNames.joined(separator: " and "))."

    return "\(deletionDescription) Snipe-IT status “\(targetStatus.name)” will then be applied."
  }

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
        capture = DeviceProcessingCapture(start: .condition(device))
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

  private func device(for item: DeviceProcessingItem) -> Device? {
    modelContext.fetchDevice(matching: item.serial, scanType: .serial)
  }

  private func remove(_ item: DeviceProcessingItem) {
    guard item.state != .processing else { return }
    modelContext.delete(item)
    try? modelContext.save()
  }

  private func clearItems() {
    items.filter { $0.state != .processing }.forEach(modelContext.delete)
    try? modelContext.save()
    selectedStatusId = modelData.settings.lastTargetStatusId(for: profile)
  }

  @MainActor
  private func processPendingItems() async {
    guard !isProcessing, let targetStatus else { return }
    isProcessing = true
    defer { isProcessing = false }

    let coordinator = DeviceProcessingCoordinator(
      service: LiveDeviceProcessingService(settings: modelData.settings),
      modelContext: modelContext
    )

    for item in pendingItems {
      guard !Task.isCancelled else { break }
      await coordinator.process(
        item: item,
        device: device(for: item),
        targetStatusId: targetStatus.snipeItId,
        targetStatusName: targetStatus.name,
        conditionField: modelData.settings.snipeItConditionField,
        conditionNotesField: modelData.settings.snipeItConditionNotesField
      )
    }

    await modelData.cacheManager.sync()
  }

  private var saleCSV: SaleCSV? {
    guard profile == .sale, !items.isEmpty else { return nil }
    return SaleCSV(items: items, fallbackStatusName: targetStatus?.name)
  }
}
