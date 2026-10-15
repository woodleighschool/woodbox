import Foundation

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

  @MainActor
  static func delete(_ request: Request, settings: AppSettings = .shared) async throws {
    switch request.provider {
    case .jamf:
      guard let jamfClient = settings.jamfClient else {
        throw IntegrationError(
          action: "delete device",
          integration: "Jamf",
          message: "The integration is not enabled or configured"
        )
      }
      if request.jamfDeviceType == .mobile {
        try await jamfClient.deleteJamfMobileDevice(id: request.deviceId)
      } else {
        try await jamfClient.deleteJamfComputer(id: request.deviceId)
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
      } catch let error as IntegrationError where error.integration == "Intune" && error.statusCode == 404 {
        return
      }
    }
  }
}
