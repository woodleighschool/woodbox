import Foundation
import SwiftData

@Model
final class Device {
  // MARK: - Properties

  var assetTag: String
  var serial: String

  var name: String?
  var model: String
  var category: String?

  var status: String?
  var statusId: Int?
  @Attribute(.unique) var snipeItId: Int?

  var assignedUserName: String?
  var assignedUserEmail: String?
  var notes: String?
  var ram: String?
  var storage: String?
  var warrantyExpires: Date?

  // MARK: - Init

  init(serial: String, assetTag: String, model: String) {
    self.serial = serial
    self.assetTag = assetTag
    self.model = model
  }
}

// MARK: - Extensions

extension Device {
  static func symbolName(for model: String) -> String {
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

extension Device {
  @MainActor
  func update(from asset: SnipeItAssetResponse) {
    snipeItId = asset.id
    serial = asset.serial
    assetTag = asset.assetTag
    name = asset.name.nilIfEmpty
    model = asset.model.name
    category = asset.category?.name.nilIfEmpty
    status = asset.statusLabel?.name.nilIfEmpty
    statusId = asset.statusLabel?.id
    notes = asset.notes.nilIfEmpty
    ram = asset[customField: "RAM"]
    storage = asset[customField: "Storage"]
    assignedUserName = asset.assignedTo?.name.nilIfEmpty
    assignedUserEmail = asset.assignedTo?.email.nilIfEmpty
    warrantyExpires = asset.warrantyExpires?.date.flatMap { Self.dateOnlyFormatter.date(from: $0) }
  }

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()
}
