import Foundation
import SwiftData

enum MDMDeletionService {
  struct Request: Equatable, Sendable {
    let provider: MDMProvider
    let deviceId: String
    let jamfDeviceType: JamfDeviceType?

    init(provider: MDMProvider, deviceId: String, jamfDeviceType: JamfDeviceType?) {
      self.provider = provider
      self.deviceId = deviceId
      self.jamfDeviceType = jamfDeviceType
    }

    @MainActor
    init(record: MDMRecord) {
      self.init(
        provider: record.provider,
        deviceId: record.deviceId,
        jamfDeviceType: record.jamfDeviceType
      )
    }
  }

  struct LocalRecord: Equatable, Sendable {
    let provider: MDMProvider
    let deviceId: String
    let deviceName: String?
    let lastCheckIn: Date?
    let jamfDeviceType: JamfDeviceType?

    @MainActor
    init(record: MDMRecord) {
      provider = record.provider
      deviceId = record.deviceId
      deviceName = record.deviceName
      lastCheckIn = record.lastCheckIn
      jamfDeviceType = record.jamfDeviceType
    }
  }

  @MainActor
  static func delete(_ request: Request) async throws {
    let settings = AppSettings.shared

    switch request.provider {
    case .jamf:
      guard let jamfClient = settings.jamfClient else {
        throw IntegrationError(
          action: "delete device",
          integration: "Jamf",
          message: "The integration is not enabled or configured"
        )
      }
      do {
        if request.jamfDeviceType == .mobile {
          try await jamfClient.deleteJamfMobileDevice(id: request.deviceId)
        } else {
          try await jamfClient.deleteJamfComputer(id: request.deviceId)
        }
      } catch let error as IntegrationError where error.statusCode == 404 {
        return
      }

    case .intune:
      guard let intuneClient = settings.intuneClient else {
        throw IntegrationError(
          action: "delete device",
          integration: "Intune",
          message: "The integration is not enabled or configured"
        )
      }
      do {
        try await intuneClient.deleteIntuneDevice(id: request.deviceId)
      } catch let error as IntegrationError where error.statusCode == 404 {
        return
      }
    }
  }

  @MainActor
  static func removeLocally(
    _ record: MDMRecord,
    from device: Device,
    modelContext: ModelContext
  ) throws {
    device.mdmRecords.removeAll { $0.id == record.id }
    modelContext.delete(record)
    try modelContext.save()
  }

  @MainActor
  @discardableResult
  static func restoreLocally(
    _ record: LocalRecord,
    to device: Device,
    modelContext: ModelContext
  ) throws -> MDMRecord {
    let restored = MDMRecord(
      provider: record.provider,
      deviceId: record.deviceId,
      deviceName: record.deviceName,
      lastCheckIn: record.lastCheckIn,
      jamfDeviceType: record.jamfDeviceType
    )
    device.mdmRecords.append(restored)
    modelContext.insert(restored)
    try modelContext.save()
    return restored
  }
}
