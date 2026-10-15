import SwiftData
import SwiftUI

struct EnrollmentPolicyView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  @State private var searchQuery = ""
  @State private var showClearConfirmation = false
  @State private var alertItem: AlertItem?
  @State private var plan: EnrollmentAssignmentPlan?

  #if os(iOS)
    @State private var isScanning = false
  #else
    @State private var scannerInput = ""
    @State private var scanStatus: String?
    @FocusState private var scannerInputFocused: Bool
  #endif

  private var queue: EnrollmentQueue {
    modelData.enrollmentQueue
  }

  private var searchResults: [EnrollmentDevice] {
    guard let query = searchQuery.nilIfEmpty, let snapshot = queue.snapshot else { return [] }
    let assetSerials = Set(modelContext.searchDevices(matching: query).map(\.serial))
    return Array(snapshot.devices.values.filter {
      assetSerials.contains($0.serial) || $0.serial.localizedStandardContains(query)
        || $0.summary?.localizedStandardContains(query) == true
    }.sorted { $0.serial < $1.serial }.prefix(25))
  }

  private var isApplyDisabled: Bool {
    queue.targetPolicy == nil
      || queue.serials.isEmpty
      || queue.loadState == .loading
  }

  var body: some View {
    Group {
      if !modelData.settings.intuneIsEnabled {
        ContentUnavailableView(
          "No Intune Connection",
          systemImage: "network",
          description: Text("Enable Intune in Settings.")
        )
      } else {
        platformContent
          .overlay {
            if queue.snapshot == nil {
              ToolLoadingView(title: "Loading enrollment", state: queue.loadState)
                .allowsHitTesting(false)
            }
          }
      }
    }
    .toolRefreshable(state: queue.loadState, failurePolicy: modelData.enrollmentRefreshFailures, disabled: !modelData.settings.intuneIsEnabled) { _ in
      await queue.refresh()
      return queue.loadState
    }
    .searchable(text: $searchQuery, prompt: "Add a Device")
    .searchSuggestions {
      ForEach(searchResults, id: \.serial) { device in
        Button {
          addFromSearch(device)
        } label: {
          EnrollmentDeviceLabel(serial: device.serial, enrolled: device) { EmptyView() }
        }
      }
    }
    .onSubmit(of: .search) {
      guard let device = searchResults.first else { return }
      addFromSearch(device)
    }
    .confirmationDialog(
      "Clear Enrollment Queue?",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear Queue", role: .destructive, action: queue.clear)
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
    .sheet(item: $plan) { plan in
      EnrollmentPolicyApplyView(plan: plan)
      #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
      #endif
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
        if queue.snapshot != nil {
          Section {
            policyPicker
          } header: {
            Text("Destination")
          }
        }

        if queue.snapshot != nil, queue.serials.isEmpty {
          ContentUnavailableView {
            Label("No Devices", systemImage: "barcode.viewfinder")
          } description: {
            Text("Use Search, Scan, or Add from Policy to build the enrollment queue.")
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        } else if !queue.serials.isEmpty {
          Section {
            ForEach(queue.serials, id: \.self) { serial in
              EnrollmentQueueRow(serial: serial, snapshot: queue.snapshot)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                  Button("Remove", systemImage: "trash", role: .destructive) {
                    queue.remove(serial: serial)
                  }
                }
            }
          } header: {
            Text("Devices")
          } footer: {
            deviceCount
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .toolbar { iOSToolbar }
      .sheet(isPresented: $isScanning) {
        EnrollmentScannerSheet(queue: queue)
          .presentationDetents([.medium])
          .presentationDragIndicator(.visible)
      }
    }

    @ToolbarContentBuilder
    private var iOSToolbar: some ToolbarContent {
      ScanSearchToolbar {
        isScanning = true
      }

      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          addFromPolicyMenu

          Button("Clear Queue", systemImage: "trash", role: .destructive) {
            showClearConfirmation = true
          }
          .disabled(queue.serials.isEmpty)
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }

      ToolbarItem(placement: .confirmationAction) {
        Button("Apply", action: presentPlan)
          .disabled(isApplyDisabled)
          .buttonStyle(.borderedProminent)
      }
    }

  #else
    private var macOSContent: some View {
      VStack(spacing: 0) {
        if queue.snapshot != nil {
          macOSControls
        }

        if let scanStatus {
          Text(scanStatus)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }

        Divider()

        if queue.snapshot == nil {
          Spacer()
        } else if queue.serials.isEmpty {
          ContentUnavailableView(
            "No Devices",
            systemImage: "barcode.viewfinder",
            description: Text("Scan an asset tag or serial number, or add the devices on a policy.")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List(queue.serials, id: \.self) { serial in
            HStack(spacing: 12) {
              EnrollmentQueueRow(serial: serial, snapshot: queue.snapshot)

              Button("Remove", systemImage: "trash", role: .destructive) {
                queue.remove(serial: serial)
              }
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
            }
          }
        }
      }
      .navigationSubtitle(queue.serials.isEmpty ? Text(verbatim: "") : deviceCount)
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

        policyPicker
          .frame(minWidth: 240)
      }
      .padding(12)
    }

    @ToolbarContentBuilder
    private var macOSToolbar: some ToolbarContent {
      ToolbarItemGroup(placement: .primaryAction) {
        addFromPolicyMenu

        Button("Clear Queue", systemImage: "trash", role: .destructive) {
          showClearConfirmation = true
        }
        .disabled(queue.serials.isEmpty)

        Button("Apply", systemImage: "checkmark", action: presentPlan)
          .disabled(isApplyDisabled)
          .keyboardShortcut(.return, modifiers: [.command])
      }
    }

    private func addScannerInput() {
      let value = scannerInput.trimmingCharacters(in: .whitespacesAndNewlines)
      scannerInput = ""
      scannerInputFocused = true
      guard !value.isEmpty else { return }

      // A serial missing from Snipe-IT can still match an enrollment program device.
      let device = modelContext.fetchDevice(matchingIdentifier: value)
      let serial = device?.serial ?? value.uppercased()
      let result = queue.add(serial: serial)

      // A USB scanner keeps typing, so its results show inline instead of in an alert.
      if device == nil, result == .notEnrolled {
        scanStatus = "No device matches “\(value)”."
      } else {
        let label = device?.assetTag ?? serial
        scanStatus = result.failureMessage(label: label) ?? "Added \(queue.describe(serial: serial, as: label))."
      }
    }
  #endif

  private var policyPicker: some View {
    @Bindable var queue = queue

    return Picker("Assign Policy", selection: $queue.targetPolicyId) {
      Text("Choose Policy").tag(nil as String?)

      if let snapshot = queue.snapshot {
        ForEach(snapshot.policies.filter(\.isAssignable)) { policy in
          Text(policy.name).tag(Optional(policy.id))
        }
      }
    }
    .disabled(queue.snapshot == nil)
  }

  private var addFromPolicyMenu: some View {
    Menu("Add from Policy", systemImage: "plus.rectangle.on.rectangle") {
      if let snapshot = queue.snapshot {
        ForEach(snapshot.policies) { policy in
          let count = snapshot.deviceCount(policyId: policy.id)
          Button("\(policy.name) (\(count))") {
            queue.addDevices(policyId: policy.id)
          }
          .disabled(count == 0)
        }

        let unassignedCount = snapshot.deviceCount(policyId: nil)
        if unassignedCount > 0 {
          Section {
            Button("No Policy (\(unassignedCount))") {
              queue.addDevices(policyId: nil)
            }
          }
        }

        let unrecognizedPolicyIds = snapshot.unrecognizedPolicyIds
        if !unrecognizedPolicyIds.isEmpty {
          Section("Unknown Policies") {
            ForEach(unrecognizedPolicyIds, id: \.self) { policyId in
              Button("\(policyId) (\(snapshot.deviceCount(policyId: policyId)))") {
                queue.addDevices(policyId: policyId)
              }
            }
          }
        }
      }
    }
    .disabled(queue.snapshot == nil)
  }

  private var deviceCount: Text {
    Text("^[\(queue.serials.count) device](inflect: true)")
  }

  private func addFromSearch(_ device: EnrollmentDevice) {
    searchQuery = ""
    if let message = queue.add(serial: device.serial).failureMessage(label: device.serial) {
      alertItem = AlertItem(title: "Unable to Add Device", message: message)
    }
  }

  private func presentPlan() {
    guard let target = queue.targetPolicy, let snapshot = queue.snapshot else { return }
    plan = EnrollmentAssignmentPlan(serials: queue.serials, target: target, snapshot: snapshot)
  }
}

// MARK: - Subviews

private struct EnrollmentQueueRow: View {
  let serial: String
  let snapshot: EnrollmentSnapshot?

  var body: some View {
    EnrollmentDeviceLabel(serial: serial, enrolled: snapshot?.devices[serial]) {
      if let snapshot {
        Text("\(Image(systemName: "doc.badge.gearshape.fill")) \(snapshot.policyDescription(serial: serial))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct EnrollmentDeviceLabel<Details: View>: View {
  @Environment(\.modelContext) private var modelContext

  let serial: String
  let enrolled: EnrollmentDevice?
  @ViewBuilder let details: Details

  var body: some View {
    let device = modelContext.fetchDevice(serial: serial)
    DeviceIdentityLabel(
      device: device,
      name: device?.name,
      model: device?.model ?? enrolled?.summary ?? "Model not reported",
      assetTag: device?.assetTag,
      serial: serial
    ) {
      details
    }
  }
}

#if os(iOS)
  private struct EnrollmentScannerSheet: View {
    let queue: EnrollmentQueue

    @State private var session = DeviceScanSession()

    var body: some View {
      NavigationStack {
        DeviceScanner(
          session: $session,
          title: "Scan Devices",
          subtitle: "Keep scanning to build the queue",
          showsCount: true,
          onDevice: add,
          additionalSerials: Array(queue.snapshot?.devices.keys ?? [String: EnrollmentDevice]().keys),
          onSerial: { add(serial: $0, label: $0) }
        )
      }
      .sensoryFeedback(.success, trigger: session.addedSerials.count)
    }

    private func add(_ device: Device) {
      add(serial: device.serial, label: device.assetTag)
    }

    private func add(serial: String, label: String) {
      let result = queue.add(serial: serial)
      switch result {
      case .added:
        session.added(serial: serial, label: queue.describe(serial: serial, as: label))
      case .alreadyListed where session.addedSerials.contains(serial):
        // The camera often lingers on a device it has just added.
        break
      default:
        if let message = result.failureMessage(label: serial) {
          session.report(message)
        }
      }
    }
  }
#endif
