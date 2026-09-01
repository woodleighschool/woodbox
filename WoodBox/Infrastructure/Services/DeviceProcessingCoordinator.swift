import Foundation
import SwiftData

nonisolated enum DeviceProcessingOutcome: Equatable, Sendable {
  case applied
  case failed(String)
}

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
    conditionNotesField: String,
    progress: (String) -> Void = { _ in }
  ) async -> DeviceProcessingOutcome {
    guard let device, let assetId = device.snipeItId else {
      return .failed(
        IntegrationError(
          action: "process device",
          integration: "Snipe-IT",
          message: "No matching Snipe-IT asset is available"
        ).localizedDescription
      )
    }

    do {
      for record in device.mdmRecords.sorted(by: {
        $0.provider.processingOrder < $1.provider.processingOrder
      }) {
        try Task.checkCancellation()
        progress("Deleting from \(record.provider.rawValue)")

        let request = MDMDeletionService.Request(record: record)
        do {
          try await service.deleteMDMRecord(request)
        } catch {
          return .failed(error.localizedDescription)
        }

        try MDMDeletionService.removeLocally(
          record,
          from: device,
          modelContext: modelContext
        )
      }

      try Task.checkCancellation()
      progress("Updating Snipe-IT")

      let customFields = customFields(
        for: item,
        conditionField: conditionField,
        conditionNotesField: conditionNotesField
      )
      let wasAssigned = device.assignedUserName != nil || device.assignedUserEmail != nil

      do {
        if wasAssigned {
          try await service.checkInSnipeItAsset(assetId: assetId, statusId: targetStatusId)
          device.statusId = targetStatusId
          device.status = targetStatusName
          device.assignedUserName = nil
          device.assignedUserEmail = nil
          try save()

          if !customFields.isEmpty {
            try await service.updateSnipeItAsset(
              assetId: assetId,
              statusId: nil,
              customFields: customFields
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
        return .failed(error.localizedDescription)
      }

      device.statusId = targetStatusId
      device.status = targetStatusName
      try save()
      return .applied
    } catch is CancellationError {
      return .failed("Processing was cancelled.")
    } catch {
      return .failed(error.localizedDescription)
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

  private func save() throws {
    try modelContext.save()
  }
}
