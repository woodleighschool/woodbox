import Foundation

struct MDMInventoryService {
  let settings: AppSettings

  func fetch(serial: String? = nil) async throws -> [MDMRecord] {
    let serial = serial?.trimmingCharacters(in: .whitespacesAndNewlines)
    if serial?.isEmpty == true {
      throw IntegrationError(action: "find MDM records", integration: "MDM", message: "A serial number is required")
    }
    let jamf = settings.jamfIsEnabled ? try require(settings.jamfClient, provider: "Jamf") : nil
    let intune = settings.intuneIsEnabled ? try require(settings.intuneClient, provider: "Intune") : nil
    async let computers = jamf?.fetchJamfComputers(serial: serial) ?? []
    async let mobiles = jamf?.fetchJamfMobileDevices(serial: serial) ?? []
    async let managedDevices = intune?.fetchIntuneDevices(serial: serial) ?? []

    let records = try await computers.map {
      MDMRecord(
        provider: .jamf,
        deviceId: $0.id,
        serial: $0.hardware.serialNumber,
        deviceName: $0.general.name.nilIfEmpty,
        lastCheckIn: Self.date($0.general.lastContactTime),
        jamfDeviceType: .computer,
        model: $0.hardware.model
      )
    } + mobiles.map {
      MDMRecord(
        provider: .jamf,
        deviceId: $0.mobileDeviceId,
        serial: $0.hardware.serialNumber,
        deviceName: $0.name.nilIfEmpty,
        lastCheckIn: Self.date($0.general.lastInventoryUpdateDate),
        jamfDeviceType: .mobile,
        model: $0.hardware.model
      )
    } + managedDevices.map {
      MDMRecord(
        provider: .intune,
        deviceId: $0.id,
        serial: $0.serialNumber,
        deviceName: $0.deviceName.nilIfEmpty,
        lastCheckIn: Self.date($0.lastSyncDateTime),
        jamfDeviceType: nil,
        model: $0.model
      )
    }
    try Task.checkCancellation()
    // Validate the match locally before handing records to a destructive operation.
    return records.filter { record in
      serial.map { record.serial.caseInsensitiveCompare($0) == .orderedSame } ?? true
    }
  }

  private func require<Client>(_ client: Client?, provider: String) throws -> Client {
    guard let client else {
      throw IntegrationError(action: "load devices", integration: provider, message: "Required settings are missing")
    }
    return client
  }

  private static func date(_ value: String?) -> Date? {
    value.flatMap { try? Date($0, strategy: .iso8601) }
  }
}
