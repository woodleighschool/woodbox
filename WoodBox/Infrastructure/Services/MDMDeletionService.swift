import Foundation
import SwiftData

enum MDMDeletionService {
  struct Request {
    let provider: MDMProvider
    let deviceId: String
    let jamfDeviceType: JamfDeviceType?
  }

  @MainActor
  static func delete(_ request: Request) async throws {
    let settings = AppSettings.shared

    switch request.provider {
    case .jamf:
      guard let jamfClient = settings.jamfClient else { return }
      if request.jamfDeviceType == .mobile {
        try await jamfClient.deleteJamfMobileDevice(id: request.deviceId)
      } else {
        try await jamfClient.deleteJamfComputer(id: request.deviceId)
      }

    case .intune:
      guard let intuneClient = settings.intuneClient else { return }
      try await intuneClient.deleteIntuneDevice(id: request.deviceId)
    }
  }

  @MainActor
  static func remove(
    records: [MDMRecord],
    from device: Device,
    modelContext: ModelContext
  ) -> [Request] {
    let requests = records.map {
      Request(provider: $0.provider, deviceId: $0.deviceId, jamfDeviceType: $0.jamfDeviceType)
    }

    let recordIds = Set(records.map(\.id))
    device.mdmRecords.removeAll { recordIds.contains($0.id) }
    records.forEach(modelContext.delete)
    try? modelContext.save()

    return requests
  }

  static func delete(_ requests: [Request]) async -> [Error] {
    await withTaskGroup(of: Error?.self) { group in
      for request in requests {
        group.addTask {
          do {
            try await delete(request)
            return nil
          } catch {
            return error
          }
        }
      }

      var errors: [Error] = []
      for await error in group {
        if let error {
          errors.append(error)
        }
      }
      return errors
    }
  }
}
