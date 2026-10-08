import Foundation
import SwiftData

nonisolated enum DeviceProcessingProfile: String, Codable, CaseIterable, Identifiable {
  case restock
  case sale

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .restock: "Restock"
    case .sale: "Sale"
    }
  }

  var symbol: String {
    switch self {
    case .restock: "arrow.uturn.left.circle"
    case .sale: "tag"
    }
  }

  var requiresCondition: Bool {
    self == .sale
  }
}

nonisolated enum DeviceProcessingDraft {
  case restock(Device)
  case sale(Device, grade: SaleGrade, conditionNotes: String)

  var device: Device {
    switch self {
    case let .restock(device), let .sale(device, _, _):
      device
    }
  }

  var profile: DeviceProcessingProfile {
    switch self {
    case .restock: .restock
    case .sale: .sale
    }
  }

  var grade: SaleGrade? {
    switch self {
    case .restock: nil
    case let .sale(_, grade, _): grade
    }
  }

  var conditionNotes: String {
    switch self {
    case .restock: ""
    case let .sale(_, _, conditionNotes):
      conditionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}

@Model
final class DeviceProcessingItem {
  #Unique<DeviceProcessingItem>([\.profileRawValue, \.serial])

  var profileRawValue: String

  var serial: String
  var assetTag: String
  var deviceName: String?
  var deviceModel: String
  var addedAt: Date

  var gradeRawValue: String?
  var conditionNotes: String

  init(_ draft: DeviceProcessingDraft, addedAt: Date = .now) {
    let device = draft.device
    profileRawValue = draft.profile.rawValue
    serial = device.serial
    assetTag = device.assetTag
    deviceName = device.name
    deviceModel = device.model
    self.addedAt = addedAt
    gradeRawValue = draft.grade?.rawValue
    conditionNotes = draft.conditionNotes
  }
}

extension DeviceProcessingItem {
  /// Takes on what the cache knows about the device. An item keeps its own copy of these details
  /// so that a device can leave the cache without leaving the list.
  func update(from device: Device) {
    assetTag = device.assetTag
    deviceName = device.name
    deviceModel = device.model
  }

  var profile: DeviceProcessingProfile {
    get { DeviceProcessingProfile(rawValue: profileRawValue) ?? .restock }
    set {
      profileRawValue = newValue.rawValue
    }
  }

  var grade: SaleGrade? {
    get { gradeRawValue.flatMap(SaleGrade.init(rawValue:)) }
    set { gradeRawValue = newValue?.rawValue }
  }
}
