//
//  RepairIntakeView.swift
//  WoodBox
//
//  Created by Alexander Hyde on 17/2/2026.
//

import SwiftData
import SwiftUI

struct RepairIntakeView: View {
  // MARK: - Properties

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
  @State private var isSubmitting = false
  @State private var alertItem: AlertItem?

  // MARK: - Computed Properties

  private var canCreateFreshserviceTicket: Bool {
    form.endUserEmail.nilIfEmpty != nil
  }

  private var canCheckoutSpare: Bool {
    form.selectedSpare != nil
  }

  private var isSubmitDisabled: Bool {
    deviceSelection.selectedDevice == nil || form.problem.nilIfEmpty == nil || isSubmitting
  }

  // MARK: - Body

  var body: some View {
    formContent
      .formStyle(.grouped)
      .deviceSearch(selection: deviceSelection)
      .scrollDismissesKeyboard(.interactively)
      .refreshable {
        await modelData.cacheManager.sync()
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          if isSubmitting {
            ProgressView().controlSize(.small)
          } else {
            Button {
              Task { await submit() }
            } label: {
              Image(systemName: "arrow.up")
            }
            .disabled(isSubmitDisabled)
            .buttonStyle(.borderedProminent)
          }
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
      TextField("Problem", text: $form.problem, prompt: Text("e.g. Broken Screen"))

      if modelData.settings.snipeItIsEnabled {
        SpareDevicePicker(
          nameRegex: modelData.settings.snipeItSpareDeviceNameRegex,
          selection: $form.selectedSpare
        )
        .onChange(of: modelData.settings.snipeItSpareDeviceNameRegex) { _, _ in
          form.selectedSpare = nil
        }
      }

      TextField(
        "Notes", text: $form.notes,
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
      TextField("Email", text: $form.endUserEmail)
    } header: {
      Label("End User", systemImage: "person.crop.circle")
    }
  }

  private var automationSection: some View {
    Section {
      if modelData.settings.compnowIsEnabled {
        Toggle(isOn: $form.createCompnowTicket) {
          Label {
            Text("Create Compnow Ticket")
          } icon: {
            Image("compnow")
              .resizable()
              .scaledToFit()
          }
        }
      }

      if modelData.settings.freshserviceIsEnabled {
        Toggle(isOn: $form.createFreshserviceTicket) {
          Label {
            Text("Create Freshservice Ticket")
          } icon: {
            Image("freshservice")
              .resizable()
              .scaledToFit()
          }
        }
        .disabled(!canCreateFreshserviceTicket)
      }

      if modelData.settings.snipeItIsEnabled {
        Toggle(isOn: $form.checkoutSpare) {
          Label {
            Text("Checkout Spare to End User")
          } icon: {
            Image("snipeit")
              .resizable()
              .scaledToFit()
          }
        }
        .disabled(!canCheckoutSpare)
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
      var compnowTicketId: String?

      if form.createCompnowTicket, let compnowClient = modelData.settings.compnowClient {
        // Create Compnow ticket
        let ticket = CompnowTicketCreateRequest(
          product: device.model,
          serial: device.serial,
          firstName: form.endUserName,
          lastName: "",
          address1: modelData.settings.compnowAddress,
          suburb: modelData.settings.compnowSuburb,
          state: modelData.settings.compnowState,
          postcode: modelData.settings.compnowPostcode,
          email: modelData.settings.compnowEmail,
          phone: modelData.settings.compnowPhone,
          stockCode: nil,
          extras: nil,
          fault: form.problem,
          condition: nil,
          reference: nil
        )

        compnowTicketId = try await compnowClient.createCompnowTicket(ticket)
      }

      if form.createFreshserviceTicket,
         let freshserviceClient = modelData.settings.freshserviceClient
      {
        // Create Freshservice ticket
        var customFields: [String: String] = [:]
        if let spare = form.selectedSpare, !modelData.settings.freshserviceSpareField.isEmpty,
           let spareName = spare.name
        {
          customFields[modelData.settings.freshserviceSpareField] = spareName
        }
        if let cnTicket = compnowTicketId, !modelData.settings.freshserviceCompnowField.isEmpty {
          customFields[modelData.settings.freshserviceCompnowField] = cnTicket
        }

        let ticket = FreshserviceTicketRequest(
          email: form.endUserEmail,
          subject: "REPAIR - \(form.problem)",
          description: form.notes,
          status: .open,
          priority: .low,
          tags: ["repair"], // Hardcoded specific
          customFields: customFields,
          workspaceId: modelData.settings.freshserviceWorkspaceId
        )

        _ = try await freshserviceClient.createFreshserviceTicket(ticket)
      }

      if form.checkoutSpare, let spare = form.selectedSpare,
         // Checkout spare to user
         let spareId = spare.snipeItId,
         let snipeItClient = modelData.settings.snipeItClient
      {
        let email: String? = form.endUserEmail
        let descriptor = FetchDescriptor<SnipeItUser>(
          predicate: #Predicate<SnipeItUser> { $0.email == email }
        )
        let matchingUsers = try modelContext.fetch(descriptor)
        guard let snipeUser = matchingUsers.first else {
          throw IntegrationError(
            action: "checkout spare", integration: "Snipe-IT",
            message: "No Snipe-IT user found for \(form.endUserEmail)"
          )
        }
        let statusId = spare.statusId ?? 0
        try? await snipeItClient.checkinSnipeItAsset(
          assetId: spareId,
          request: SnipeItCheckinRequest(
            statusId: statusId,
            name: nil,
            note: nil,
            locationId: nil
          )
        )

        let checkout = SnipeItCheckoutRequest(
          assignedUser: snipeUser.snipeItId, statusId: statusId, note: nil
        )
        try await snipeItClient.checkoutSnipeItAsset(assetId: spareId, request: checkout)
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
      form.createFreshserviceTicket = false
      return
    }

    form.endUserName = device.assignedUserName ?? ""
    form.endUserEmail = device.assignedUserEmail ?? ""
    form.createFreshserviceTicket = canCreateFreshserviceTicket
    if !canCheckoutSpare {
      form.checkoutSpare = false
    }
  }
}

// MARK: - Subviews

private struct SpareDevicePicker: View {
  @Query private var devices: [Device]
  @Binding var selection: Device?
  let nameRegex: String

  init(nameRegex: String, selection: Binding<Device?>) {
    self.nameRegex = nameRegex
    _selection = selection
    _devices = Query(
      sort: \Device.name
    )
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
