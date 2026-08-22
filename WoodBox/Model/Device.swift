import Foundation
import SwiftData

@Model
final class Device {
  // MARK: - Properties

  @Attribute(.unique) var assetTag: String
  var serial: String

  var name: String?
  var model: String
  var category: String?

  var status: String?
  var statusId: Int?
  var snipeItId: Int?

  var assignedUserName: String?
  var assignedUserEmail: String?
  var notes: String?
  var ram: String?
  var storage: String?
  var warrantyExpires: Date?

  @Relationship(deleteRule: .cascade) var mdmRecords: [MDMRecord]

  // MARK: - Init

  init(serial: String, assetTag: String, model: String) {
    self.serial = serial
    self.assetTag = assetTag
    self.model = model
    mdmRecords = []
  }
}

@Model
final class MDMRecord {
  @Attribute(.unique) var id: String
  var provider: MDMProvider
  var deviceId: String
  var deviceName: String?
  var lastCheckIn: Date?
  var jamfDeviceType: JamfDeviceType?

  @Relationship(inverse: \Device.mdmRecords) var device: Device?

  init(
    provider: MDMProvider,
    deviceId: String,
    deviceName: String?,
    lastCheckIn: Date?,
    jamfDeviceType: JamfDeviceType?,
    device: Device? = nil
  ) {
    id = Self.makeId(provider: provider, jamfDeviceType: jamfDeviceType, deviceId: deviceId)
    self.provider = provider
    self.deviceId = deviceId
    self.deviceName = deviceName
    self.lastCheckIn = lastCheckIn
    self.jamfDeviceType = jamfDeviceType
    self.device = device
  }

  /// Jamf IDs can sometimes overlap between mobile and computer records.
  private static func makeId(
    provider: MDMProvider, jamfDeviceType: JamfDeviceType?, deviceId: String
  ) -> String {
    "\(provider.rawValue)-\(jamfDeviceType?.rawValue ?? "na")-\(deviceId)"
  }
}

enum MDMProvider: String, Codable, CaseIterable, Identifiable {
  case jamf = "Jamf"
  case intune = "Intune"

  var id: String {
    rawValue
  }
}

enum JamfDeviceType: String, Codable {
  case computer = "Computer"
  case mobile = "Mobile"
}

// MARK: - Extensions

extension Device {
  var hasSnipeItAsset: Bool {
    snipeItId != nil
  }

  var mdmProviderNames: [String] {
    var providers: [String] = []
    if mdmRecords.contains(where: { $0.provider == .jamf }) {
      providers.append(MDMProvider.jamf.rawValue)
    }
    if mdmRecords.contains(where: { $0.provider == .intune }) {
      providers.append(MDMProvider.intune.rawValue)
    }
    return providers
  }

  var symbolName: String {
    let rules: [(String, String)] = [
      ("MacBook", "laptopcomputer"),
      ("iMac", "desktopcomputer"),
      ("Mac mini", "macmini"),
      ("Mac Pro", "macpro.gen3"),
      ("Mac Studio", "macstudio"),
      ("iPad", "ipad"),
      ("iPhone", "iphone"),
      ("iPod", "ipodtouch"),
      ("Apple TV", "appletv"),
    ]
    return rules.first(where: { model.contains($0.0) })?.1 ?? "questionmark"
  }
}
