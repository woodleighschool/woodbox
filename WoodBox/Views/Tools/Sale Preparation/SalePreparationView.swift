//
//  SalePreparationView.swift
//  WoodBox
//
//  Created by Alexander Hyde on 17/2/2026.
//

import SwiftData
import SwiftUI

struct SalePreparationView: View {
  // MARK: - Properties

  @Environment(\.modelContext) private var modelContext
  @Environment(ModelData.self) private var modelData

  @Query(sort: [SortDescriptor(\SnipeItStatus.name)])
  private var snipeStatuses: [SnipeItStatus]

  @Bindable var deviceSelection: DeviceSelectionState

  private struct FormState {
    var condition: DeviceCondition = .a
    var conditionDescription = ""
    var selectedSnipeStatusId: Int?
    var deleteInMDM = false
  }

  @State private var form = FormState()
  @State private var isSubmitting = false
  @State private var alertItem: AlertItem?
  @State private var showDeleteConfirmation = false
  @State private var showGradeHelp = false

  // MARK: - Computed Properties

  private var canUpdateSnipeIt: Bool {
    deviceSelection.selectedDevice?.hasSnipeItAsset == true
  }

  private var selectedSnipeStatusName: String? {
    guard let statusId = form.selectedSnipeStatusId else { return nil }
    return snipeStatuses.first { $0.snipeItId == statusId }?.name
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
        Button("Delete", role: .destructive) { Task { await submit() } }
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
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Picker("Condition Grade", selection: $form.condition) {
          ForEach(DeviceCondition.allCases, id: \.self) { condition in
            Text(condition.rawValue).tag(condition)
          }
        }
        .pickerStyle(.segmented)

        Button {
          showGradeHelp = true
        } label: {
          Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showGradeHelp) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Grade Guide")
              .font(.headline)
            ForEach(DeviceCondition.allCases, id: \.self) { condition in
              gradeRow(condition)
            }
          }
          .presentationCompactAdaptation(.sheet)
        }
      }

      TextField(
        "Condition Description",
        text: $form.conditionDescription,
        prompt: Text("Broken chinbar, missing some keys."),
        axis: .vertical
      )
      .lineLimit(3 ... 6)
    } header: {
      Label("Details", systemImage: "pencil")
    }
  }

  private var automationSection: some View {
    Section {
      if modelData.settings.snipeItIsEnabled {
        SnipeStatusPicker("Snipe-IT Status", selection: $form.selectedSnipeStatusId)
          .disabled(!canUpdateSnipeIt)
      }

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
        for record in device.mdmRecords {
          try await MDMDeletionService.deleteAndRemove(
            record: record,
            from: device,
            modelContext: modelContext
          )
        }
      }

      if let statusId = form.selectedSnipeStatusId,
         let assetId = device.snipeItId,
         let snipeItClient = modelData.settings.snipeItClient
      {
        var customFields: [String: String] = [:]

        if !modelData.settings.snipeItConditionField.isEmpty {
          customFields[modelData.settings.snipeItConditionField] = form.condition.rawValue
        }
        if !form.conditionDescription.isEmpty,
           !modelData.settings.snipeItConditionNotesField.isEmpty
        {
          customFields[modelData.settings.snipeItConditionNotesField] = form.conditionDescription
        }

        try await snipeItClient.updateSnipeItAsset(
          assetId: assetId,
          request: SnipeItUpdateRequest(
            statusId: statusId,
            notes: nil,
            customFields: customFields.isEmpty ? nil : customFields
          )
        )
        device.statusId = statusId
        device.status = selectedSnipeStatusName
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
    form.selectedSnipeStatusId = nil
    if activeProviders.isEmpty {
      form.deleteInMDM = false
    }
  }

  private func gradeRow(_ condition: DeviceCondition) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Text(condition.rawValue)
        .font(.headline)
        .frame(width: 18, alignment: .leading)

      Text(condition.detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}
