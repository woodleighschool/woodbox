import SwiftData
import SwiftUI

struct ReturnCheckInView: View {
  // MARK: - Properties

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  @Query(sort: [SortDescriptor(\SnipeItStatus.name)])
  private var snipeStatuses: [SnipeItStatus]

  @Bindable var deviceSelection: DeviceSelectionState

  private struct FormState {
    var endUserName = ""
    var endUserEmail = ""
    var goodCondition = true
    var hasCharger = true
    var deleteInMDM = false
    var selectedSnipeStatusId: Int?
    var createFreshserviceRequest = false
    var notes = ""
  }

  @State private var form = FormState()
  @State private var isSubmitting = false
  @State private var alertItem: AlertItem?
  @State private var showDeleteConfirmation = false

  // MARK: - Computed Properties

  private var canUpdateSnipeIt: Bool {
    deviceSelection.selectedDevice?.hasSnipeItAsset == true
  }

  private var selectedSnipeStatusName: String? {
    guard let statusId = form.selectedSnipeStatusId else { return nil }
    return snipeStatuses.first { $0.snipeItId == statusId }?.name
  }

  private var canCreateFreshserviceRequest: Bool {
    form.endUserEmail.nilIfEmpty != nil
  }

  private var activeProviders: [String] {
    deviceSelection.selectedDevice?.mdmProviderNames ?? []
  }

  private var isSubmitDisabled: Bool {
    deviceSelection.selectedDevice == nil || isSubmitting
  }

  // MARK: - Body

  var body: some View {
    formContent
      .formStyle(.grouped)
      .deviceSearch(selection: deviceSelection)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          if isSubmitting {
            ProgressView().controlSize(.small)
          } else {
            Button {
              if form.deleteInMDM, !activeProviders.isEmpty {
                showDeleteConfirmation = true
              } else {
                Task { await submit() }
              }
            } label: {
              Image(systemName: "arrow.up")
            }
            .disabled(isSubmitDisabled)
            .buttonStyle(.borderedProminent)
          }
        }
      }
      .alert("Confirm MDM Deletion", isPresented: $showDeleteConfirmation) {
        Button("Delete", role: .destructive) {
          Task { await submit() }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This will delete the device from \(activeProviders.joined(separator: " and ")).")
      }
      .alert(item: $alertItem) { item in
        Alert(
          title: Text(item.title),
          message: Text(item.message),
          dismissButton: .default(Text("OK"))
        )
      }
      .onChange(of: deviceSelection.selectedDevice?.serial, initial: true) { _, _ in
        syncFormWithSelection()
      }
  }

  // MARK: - View Builders

  private var formContent: some View {
    Form {
      deviceSection
      detailsSection
      endUserSection
      automationSection
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
      Toggle("Good Condition", isOn: $form.goodCondition)
      Toggle("Has Charger", isOn: $form.hasCharger)
      TextField(
        "Notes", text: $form.notes, prompt: Text("Missing some keys, will be $149 to be fixed..."),
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
      TextField("Email", text: $form.endUserEmail)
    } header: {
      Label("End User", systemImage: "person.crop.circle")
    }
  }

  private var automationSection: some View {
    Section {
      if !activeProviders.isEmpty {
        Toggle(isOn: $form.deleteInMDM) {
          Label {
            Text("Delete device from \(activeProviders.joined(separator: " and "))")
          } icon: {
            Image(systemName: "trash")
              .foregroundStyle(.red)
          }
        }
      }

      if modelData.settings.snipeItIsEnabled {
        SnipeStatusPicker("Snipe-IT Status", selection: $form.selectedSnipeStatusId)
          .disabled(!canUpdateSnipeIt)
      }

      if modelData.settings.freshserviceIsEnabled {
        Toggle(isOn: $form.createFreshserviceRequest) {
          Label {
            Text("Create Service Request")
          } icon: {
            Image(systemName: "ticket")
          }
        }
        .disabled(!canCreateFreshserviceRequest)
      }
    } header: {
      Label("Automation", systemImage: "point.3.filled.connected.trianglepath.dotted")
    }
  }

  // MARK: - Private Helpers

  @MainActor
  private func submit() async {
    guard !isSubmitting, let device = deviceSelection.selectedDevice else { return }
    isSubmitting = true
    defer { isSubmitting = false }
    alertItem = nil

    do {
      if form.deleteInMDM {
        let requests = MDMDeletionService.remove(
          records: Array(device.mdmRecords),
          from: device,
          modelContext: modelContext
        )
        Task { @MainActor in
          let errors = await MDMDeletionService.delete(requests)
          if let error = errors.first {
            alertItem = .error(error)
          }
        }
      }

      if let statusId = form.selectedSnipeStatusId, let assetId = device.snipeItId,
         let snipeItClient = modelData.settings.snipeItClient
      {
        try await snipeItClient.checkinSnipeItAsset(
          assetId: assetId,
          request: SnipeItCheckinRequest(
            statusId: statusId,
            name: nil,
            note: "Returned via WoodBox",
            locationId: nil
          )
        )
        device.statusId = statusId
        device.status = selectedSnipeStatusName
        device.assignedUserName = nil
        device.assignedUserEmail = nil
      }

      if form.createFreshserviceRequest,
         let freshserviceClient = modelData.settings.freshserviceClient
      {
        // Create Freshservice service request
        var customFields: [String: String] = [:]
        if !modelData.settings.freshserviceReturnConditionField.isEmpty {
          customFields[modelData.settings.freshserviceReturnConditionField] =
            form.goodCondition ? "Yes" : "No"
        }
        if !modelData.settings.freshserviceReturnChargerField.isEmpty {
          customFields[modelData.settings.freshserviceReturnChargerField] =
            form.hasCharger ? "Yes" : "No"
        }
        if !modelData.settings.freshserviceReturnNotesField.isEmpty, !form.notes.isEmpty {
          customFields[modelData.settings.freshserviceReturnNotesField] = form.notes
        }

        _ = try await freshserviceClient.createFreshserviceServiceRequest(
          serviceItemId: modelData.settings.freshserviceReturnedMachineServiceItemId,
          request: FreshserviceServiceRequestCreateRequest(
            email: form.endUserEmail,
            customFields: customFields.isEmpty ? nil : customFields,
            workspaceId: modelData.settings.freshserviceWorkspaceId
          )
        )
      }

      resetForm()

    } catch {
      alertItem = .error(error)
    }
  }

  private func resetForm() {
    deviceSelection.clear()
    form = FormState()
    alertItem = nil
  }

  private func syncFormWithSelection() {
    guard let device = deviceSelection.selectedDevice else {
      form.endUserName = ""
      form.endUserEmail = ""
      form.selectedSnipeStatusId = nil
      form.createFreshserviceRequest = false
      form.deleteInMDM = false
      return
    }

    form.endUserName = device.assignedUserName ?? ""
    form.endUserEmail = device.assignedUserEmail ?? ""
    form.selectedSnipeStatusId = nil
    form.createFreshserviceRequest = canCreateFreshserviceRequest
    if activeProviders.isEmpty {
      form.deleteInMDM = false
    }
  }
}
