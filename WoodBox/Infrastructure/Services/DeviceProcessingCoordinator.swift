import Foundation
import SwiftData

@MainActor
protocol DeviceProcessingServicing {
  func deleteMDMRecord(_ request: MDMDeletionService.Request) async throws
  func checkInSnipeItAsset(assetId: Int, statusId: Int) async throws
  func updateSnipeItAsset(
    assetId: Int,
    statusId: Int?,
    customFields: [String: String]?
  ) async throws
}

@MainActor
struct LiveDeviceProcessingService: DeviceProcessingServicing {
  let settings: AppSettings

  func deleteMDMRecord(_ request: MDMDeletionService.Request) async throws {
    try await MDMDeletionService.delete(request)
  }

  func checkInSnipeItAsset(assetId: Int, statusId: Int) async throws {
    guard let client = settings.snipeItClient else {
      throw IntegrationError(
        action: "check in asset",
        integration: "Snipe-IT",
        message: "The integration is not enabled or configured"
      )
    }

    try await client.checkinSnipeItAsset(
      assetId: assetId,
      request: SnipeItCheckinRequest(
        statusId: statusId,
        name: nil,
        note: nil,
        locationId: nil
      )
    )
  }

  func updateSnipeItAsset(
    assetId: Int,
    statusId: Int?,
    customFields: [String: String]?
  ) async throws {
    guard let client = settings.snipeItClient else {
      throw IntegrationError(
        action: "update asset",
        integration: "Snipe-IT",
        message: "The integration is not enabled or configured"
      )
    }

    try await client.updateSnipeItAsset(
      assetId: assetId,
      request: SnipeItUpdateRequest(
        statusId: statusId,
        notes: nil,
        customFields: customFields
      )
    )
  }
}

@MainActor
struct DeviceProcessingCoordinator {
  let service: any DeviceProcessingServicing
  let modelContext: ModelContext

  func process(
    item: DeviceProcessingItem,
    device: Device?,
    targetStatusId: Int,
    targetStatusName: String,
    conditionField: String,
    conditionNotesField: String
  ) async {
    guard item.canProcess else { return }

    item.begin(statusId: targetStatusId, statusName: targetStatusName)
    save()

    guard let device, let assetId = device.snipeItId else {
      item.fail(
        stage: .validation,
        error: IntegrationError(
          action: "process device",
          integration: "Snipe-IT",
          message: "No matching Snipe-IT asset is available"
        )
      )
      save()
      return
    }

    do {
      for record in device.mdmRecords.sorted(by: {
        $0.provider.processingOrder < $1.provider.processingOrder
      }) {
        try Task.checkCancellation()
        item.operationMessage = "Deleting from \(record.provider.rawValue)"
        save()

        let request = MDMDeletionService.Request(record: record)
        do {
          try await service.deleteMDMRecord(request)
        } catch {
          item.fail(stage: .mdm, error: error)
          save()
          return
        }

        MDMDeletionService.removeLocally(
          record,
          from: device,
          modelContext: modelContext
        )
      }

      try Task.checkCancellation()
      item.operationMessage = "Updating Snipe-IT"
      save()

      let customFields = customFields(
        for: item,
        conditionField: conditionField,
        conditionNotesField: conditionNotesField
      )
      let wasAssigned = device.assignedUserName != nil || device.assignedUserEmail != nil

      do {
        if wasAssigned || item.snipeItCheckedIn {
          let wasAlreadyCheckedIn = item.snipeItCheckedIn
          if !item.snipeItCheckedIn {
            try await service.checkInSnipeItAsset(assetId: assetId, statusId: targetStatusId)
            item.snipeItCheckedIn = true
            device.statusId = targetStatusId
            device.status = targetStatusName
            device.assignedUserName = nil
            device.assignedUserEmail = nil
            save()
          }
          if wasAlreadyCheckedIn || !customFields.isEmpty {
            try await service.updateSnipeItAsset(
              assetId: assetId,
              statusId: wasAlreadyCheckedIn ? targetStatusId : nil,
              customFields: customFields.isEmpty ? nil : customFields
            )
          }
        } else {
          try await service.updateSnipeItAsset(
            assetId: assetId,
            statusId: targetStatusId,
            customFields: customFields
          )
        }
      } catch {
        item.fail(stage: .snipeIt, error: error)
        save()
        return
      }

      device.statusId = targetStatusId
      device.status = targetStatusName
      item.complete()
      save()
    } catch is CancellationError {
      item.fail(
        stage: .validation,
        error: CancellationError()
      )
      save()
    } catch {
      item.fail(stage: .validation, error: error)
      save()
    }
  }

  private func customFields(
    for item: DeviceProcessingItem,
    conditionField: String,
    conditionNotesField: String
  ) -> [String: String] {
    guard item.profile.requiresCondition else { return [:] }

    var fields: [String: String] = [:]
    if let grade = item.grade, let key = conditionField.nilIfEmpty {
      fields[key] = grade.rawValue
    }
    if let notes = item.conditionNotes.nilIfEmpty, let key = conditionNotesField.nilIfEmpty {
      fields[key] = notes
    }
    return fields
  }

  private func save() {
    try? modelContext.save()
  }
}
