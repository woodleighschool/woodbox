import SwiftData
import SwiftUI

struct RepairIntakeView: View {
  @Environment(ModelData.self) private var modelData
  @Environment(\.modelContext) private var modelContext

  @Bindable var deviceSelection: DeviceSelectionState

  private struct FormState {
    var selectedSpare: Device?
    var endUserName = ""
    var endUserEmail = ""
    var problem = ""
    var notes = ""
    var createCompnowTicket = true
    var createFreshserviceTicket = false
    var checkoutSpare = false
  }

  @State private var form = FormState()
  @State private var progress = RepairProgress()
  @State private var isSubmitting = false
  @State private var alertItem: AlertItem?

  private var settings: AppSettings {
    modelData.settings
  }

  private var matchingSnipeItUser: SnipeItUser? {
    guard let email = form.endUserEmail.nilIfEmpty else { return nil }
    var descriptor = FetchDescriptor<SnipeItUser>(
      predicate: #Predicate<SnipeItUser> { $0.email == email }
    )
    descriptor.fetchLimit = 1
    return try? modelContext.fetch(descriptor).first
  }

  private var hasSelectedOutcome: Bool {
    (settings.compnowIsEnabled && form.createCompnowTicket)
      || (settings.freshserviceIsEnabled && form.createFreshserviceTicket)
      || (settings.snipeItIsEnabled && form.checkoutSpare && form.selectedSpare != nil)
  }

  private var isSubmitDisabled: Bool {
    isSubmitting
      || deviceSelection.selectedDevice == nil
      || form.problem.nilIfEmpty == nil
      || !hasSelectedOutcome
  }

  var body: some View {
    Form {
      deviceSection
      detailsSection
      endUserSection
      outcomesSection
    }
    .formStyle(.grouped)
    .disabled(isSubmitting)
    #if os(iOS)
      .refreshable {
        await modelData.cacheManager.sync()
      }
    #endif
      .deviceSearch(selection: deviceSelection)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          submitButton
        }
      }
      .alert(item: $alertItem) { item in
        Alert(
          title: Text(item.title),
          message: Text(item.message),
          dismissButton: .default(Text("OK"))
        )
      }
      .onChange(of: deviceSelection.selectedDevice?.serial, initial: true) { _, _ in
        // Completed steps belong to the device they were submitted for.
        progress = RepairProgress()
        syncFormWithSelection()
      }
  }

  private var deviceSection: some View {
    Section("Device") {
      DeviceSummaryItem(
        device: deviceSelection.selectedDevice,
        onClear: deviceSelection.clear
      )
    }
  }

  private var detailsSection: some View {
    Section {
      TextField("Problem", text: $form.problem, prompt: Text("e.g. Broken Screen"))

      if settings.snipeItIsEnabled {
        SpareDevicePicker(
          nameRegex: settings.snipeItSpareDeviceNameRegex,
          selection: $form.selectedSpare
        )
        .onChange(of: settings.snipeItSpareDeviceNameRegex) { _, _ in
          form.selectedSpare = nil
        }
        .onChange(of: form.selectedSpare?.serial) { _, serial in
          if serial == nil {
            form.checkoutSpare = false
          }
        }
      }

      TextField(
        "Notes",
        text: $form.notes,
        prompt: Text(
          "Customer states device won't turn on, observed liquid pouring out of the device. Suspected liquid damage."
        ),
        axis: .vertical
      )
      .lineLimit(3 ... 6)
    } header: {
      Label("Details", systemImage: "pencil")
    }
  }

  private var endUserSection: some View {
    Section {
      TextField("Name", text: $form.endUserName)
        .textContentType(.name)
      TextField("Email", text: $form.endUserEmail)
        .textContentType(.emailAddress)
      #if os(iOS)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
      #endif
        .autocorrectionDisabled()
    } header: {
      Label("End User", systemImage: "person.crop.circle")
    }
  }

  private var outcomesSection: some View {
    Section {
      if settings.compnowIsEnabled {
        Toggle("Create Compnow Ticket", systemImage: "wrench.and.screwdriver", isOn: $form.createCompnowTicket)
      }

      if settings.freshserviceIsEnabled {
        Toggle("Create Freshservice Ticket", systemImage: "ticket", isOn: $form.createFreshserviceTicket)
      }

      if settings.snipeItIsEnabled {
        Toggle("Check Out Spare to End User", systemImage: "shippingbox", isOn: $form.checkoutSpare)
          .disabled(form.selectedSpare == nil)
      }

      if !settings.compnowIsEnabled,
         !settings.freshserviceIsEnabled,
         !settings.snipeItIsEnabled
      {
        Text("Enable a repair integration in Settings.")
          .foregroundStyle(.secondary)
      }
    } header: {
      Label("Outcomes", systemImage: "checklist")
    }
  }

  private var submitButton: some View {
    Button {
      Task { await submit() }
    } label: {
      if isSubmitting {
        ProgressView()
          .controlSize(.small)
      } else {
        Label("Submit Repair", systemImage: "paperplane")
      }
    }
    .disabled(isSubmitDisabled)
    .buttonStyle(.borderedProminent)
  }

  private func submit() async {
    guard let device = deviceSelection.selectedDevice else { return }
    let progress = progress
    var spare: RepairSpareSnapshot?
    isSubmitting = true
    defer { isSubmitting = false }

    do {
      let input = try makeSubmissionInput(for: device)
      spare = input.spare
      let coordinator = RepairCoordinator(service: LiveRepairService(settings: settings))
      try await coordinator.submit(input, progress: progress)

      resetForm()
      alertItem = AlertItem(
        title: "Repair Submitted",
        message: completedSteps(of: progress, spare: spare).joined(separator: "\n")
      )
    } catch {
      let completed = completedSteps(of: progress, spare: spare)
      let resume = completed.isEmpty
        ? ""
        : "\n\nAlready done: \(completed.joined(separator: ", ")). Submit again to finish."
      alertItem = AlertItem(
        title: "Unable to Submit Repair",
        message: error.localizedDescription + resume
      )
    }
  }

  private func makeSubmissionInput(for device: Device) throws -> RepairSubmissionInput {
    var spare: RepairSpareSnapshot?
    if settings.snipeItIsEnabled, form.checkoutSpare, let selectedSpare = form.selectedSpare {
      guard let assetId = selectedSpare.snipeItId, let statusId = selectedSpare.statusId else {
        throw IntegrationError(
          action: "check out spare",
          integration: "Snipe-IT",
          message: "The selected spare has no asset or status ID"
        )
      }
      spare = RepairSpareSnapshot(
        assetId: assetId,
        name: selectedSpare.name,
        statusId: statusId,
        isAssigned: selectedSpare.assignedUserName != nil
          || selectedSpare.assignedUserEmail != nil
      )
    }

    return RepairSubmissionInput(
      device: RepairDeviceSnapshot(serial: device.serial, model: device.model),
      endUserName: form.endUserName,
      endUserEmail: form.endUserEmail,
      problem: form.problem,
      notes: form.notes,
      createCompnowTicket: settings.compnowIsEnabled && form.createCompnowTicket,
      createFreshserviceTicket: settings.freshserviceIsEnabled && form.createFreshserviceTicket,
      spare: spare,
      snipeItUserId: matchingSnipeItUser?.snipeItId
    )
  }

  private func completedSteps(of progress: RepairProgress, spare: RepairSpareSnapshot?) -> [String] {
    var steps: [String] = []
    if let ticketId = progress.compnowTicketId {
      steps.append("Compnow ticket \(ticketId)")
    }
    if let ticketId = progress.freshserviceTicketId {
      steps.append("Freshservice ticket \(ticketId)")
    }
    if progress.spareCheckedOut {
      steps.append("\(spare?.name ?? "Spare") checked out")
    }
    return steps
  }

  private func resetForm() {
    deviceSelection.clear()
    form = FormState()
  }

  private func syncFormWithSelection() {
    guard let device = deviceSelection.selectedDevice else {
      form.endUserName = ""
      form.endUserEmail = ""
      form.createFreshserviceTicket = false
      return
    }

    form.endUserName = device.assignedUserName ?? ""
    form.endUserEmail = device.assignedUserEmail ?? ""
    form.createFreshserviceTicket = settings.freshserviceIsEnabled
      && form.endUserEmail.nilIfEmpty != nil
  }
}

private struct SpareDevicePicker: View {
  @Query private var devices: [Device]
  @Binding var selection: Device?
  let nameRegex: String

  init(nameRegex: String, selection: Binding<Device?>) {
    self.nameRegex = nameRegex
    _selection = selection
    _devices = Query(sort: \Device.name)
  }

  private var spareDevices: [Device] {
    devices.filter { DeviceNameMatcher.matches($0.name, pattern: nameRegex) }
  }

  var body: some View {
    Picker("Spare Device", selection: $selection) {
      Text("None").tag(nil as Device?)
      ForEach(spareDevices) { device in
        Text(device.name ?? device.serial).tag(device as Device?)
      }
    }
    .disabled(spareDevices.isEmpty)
  }
}
