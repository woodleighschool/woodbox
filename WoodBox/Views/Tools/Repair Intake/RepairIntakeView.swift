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
  @State private var submission = RepairSubmissionState()

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

  private var validationMessage: String? {
    guard deviceSelection.selectedDevice != nil else { return "Select a device to repair." }
    guard form.problem.nilIfEmpty != nil else { return "Describe the problem." }
    guard hasSelectedOutcome else {
      return "Select at least one repair outcome."
    }
    if settings.freshserviceIsEnabled,
       form.createFreshserviceTicket,
       form.endUserEmail.nilIfEmpty == nil
    {
      return "Enter the end-user email for Freshservice."
    }
    if form.checkoutSpare, let spare = form.selectedSpare {
      guard spare.snipeItId != nil, spare.statusId != nil else {
        return "The selected spare is missing Snipe-IT data."
      }
      guard matchingSnipeItUser != nil else {
        return "No Snipe-IT user matches the end-user email."
      }
    }
    return nil
  }

  var body: some View {
    Form {
      deviceSection
        .disabled(submission.hasStarted)
      detailsSection
        .disabled(submission.hasStarted)
      endUserSection
        .disabled(submission.hasStarted)
      outcomesSection
      if submission.hasStarted {
        progressSection
      }
    }
    .formStyle(.grouped)
    #if os(iOS)
      .refreshable {
        await modelData.cacheManager.sync()
      }
    #endif
      .deviceSearch(selection: deviceSelection, isEnabled: !submission.hasStarted)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          submitButton
        }
      }
      .onChange(of: deviceSelection.selectedDevice?.serial, initial: true) { _, _ in
        guard !submission.hasStarted else { return }
        syncFormWithSelection()
      }
  }

  private var deviceSection: some View {
    Section("Device") {
      if submission.hasStarted {
        DeviceSummaryItem(device: deviceSelection.selectedDevice)
      } else {
        DeviceSummaryItem(
          device: deviceSelection.selectedDevice,
          onClear: deviceSelection.clear
        )
      }
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
      if submission.hasStarted {
        if settings.compnowIsEnabled, form.createCompnowTicket {
          RepairOutcomeRow(
            title: "Compnow repair ticket",
            systemImage: "wrench.and.screwdriver",
            value: submission.compnowTicketId
          )
        }

        if settings.freshserviceIsEnabled, form.createFreshserviceTicket {
          RepairOutcomeRow(
            title: "Freshservice ticket",
            systemImage: "ticket",
            value: submission.freshserviceTicketId
          )
        }

        if settings.snipeItIsEnabled, form.checkoutSpare, let spare = form.selectedSpare {
          RepairOutcomeRow(
            title: "Check out \(spare.name ?? spare.serial)",
            systemImage: "shippingbox",
            pendingValue: "Will check out",
            isComplete: submission.spareCheckedOut
          )
        }
      } else {
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
      }
    } header: {
      Label("Outcomes", systemImage: "checklist")
    } footer: {
      if !submission.hasStarted, let validationMessage {
        Text(validationMessage)
      }
    }
  }

  private var progressSection: some View {
    Section("Progress") {
      if submission.isRunning, let message = submission.operationMessage {
        HStack {
          ProgressView()
            .controlSize(.small)
          Text(message)
        }
      } else if submission.isComplete {
        Label("Repair submitted", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      } else if let error = submission.errorMessage {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
      }
    }
  }

  private var submitButton: some View {
    Button {
      if submission.isComplete {
        resetForm()
      } else {
        Task { await submit() }
      }
    } label: {
      if submission.isRunning {
        ProgressView()
          .controlSize(.small)
      } else {
        Label(
          submission.isComplete
            ? "New Repair"
            : (submission.hasStarted ? "Retry Repair" : "Submit Repair"),
          systemImage: submission.isComplete ? "plus" : "paperplane"
        )
      }
    }
    .disabled(
      submission.isRunning
        || (!submission.hasStarted && validationMessage != nil)
    )
    .buttonStyle(.borderedProminent)
  }

  private func submit() async {
    guard let input = makeSubmissionInput() else { return }
    let coordinator = RepairCoordinator(service: LiveRepairService(settings: settings))
    await coordinator.submit(input, state: submission)
  }

  private func makeSubmissionInput() -> RepairSubmissionInput? {
    guard let device = deviceSelection.selectedDevice else { return nil }

    let spare: RepairSpareSnapshot?
    if form.checkoutSpare, let selectedSpare = form.selectedSpare {
      guard let assetId = selectedSpare.snipeItId, let statusId = selectedSpare.statusId else {
        return nil
      }
      spare = RepairSpareSnapshot(
        assetId: assetId,
        name: selectedSpare.name,
        statusId: statusId,
        isAssigned: selectedSpare.assignedUserName != nil
          || selectedSpare.assignedUserEmail != nil
      )
    } else {
      spare = nil
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

  private func resetForm() {
    deviceSelection.clear()
    form = FormState()
    submission.reset()
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

private struct RepairOutcomeRow: View {
  let title: String
  let systemImage: String
  var value: String?
  var pendingValue = "Will create"
  var isComplete = false

  var body: some View {
    LabeledContent {
      if let value {
        Text(value)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      } else if isComplete {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
      } else {
        Text(pendingValue)
          .foregroundStyle(.secondary)
      }
    } label: {
      Label(title, systemImage: systemImage)
    }
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
