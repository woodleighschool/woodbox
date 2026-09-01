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

nonisolated enum DeviceProcessingState: String, Codable {
  case ready
  case processing
  case completed
  case failed
}

nonisolated enum DeviceProcessingFailureStage: String, Codable {
  case validation
  case mdm
  case snipeIt
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

nonisolated enum DeviceProcessingError: LocalizedError {
  case deviceNotFound(String)
  case alreadyQueued(DeviceProcessingProfile)

  var errorDescription: String? {
    switch self {
    case let .deviceNotFound(identifier):
      "No device with \(identifier) was found."
    case let .alreadyQueued(profile):
      "This device is already in the \(profile.title) queue."
    }
  }
}

@Model
final class DeviceProcessingItem {
  @Attribute(.unique) var key: String
  var profileRawValue: String

  var serial: String
  var assetTag: String
  var deviceName: String?
  var deviceModel: String
  var addedAt: Date

  var gradeRawValue: String?
  var conditionNotes: String

  var stateRawValue: String
  var failureStageRawValue: String?
  var operationMessage: String?
  var errorMessage: String?

  var targetStatusId: Int?
  var targetStatusName: String?
  var snipeItCheckedIn: Bool

  init(_ draft: DeviceProcessingDraft, addedAt: Date = .now) {
    let device = draft.device
    key = device.serial
    profileRawValue = draft.profile.rawValue
    serial = device.serial
    assetTag = device.assetTag
    deviceName = device.name
    deviceModel = device.model
    self.addedAt = addedAt
    gradeRawValue = draft.grade?.rawValue
    conditionNotes = draft.conditionNotes
    stateRawValue = DeviceProcessingState.ready.rawValue
    snipeItCheckedIn = false
  }
}

extension DeviceProcessingItem {
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

  var state: DeviceProcessingState {
    get { DeviceProcessingState(rawValue: stateRawValue) ?? .ready }
    set { stateRawValue = newValue.rawValue }
  }

  var failureStage: DeviceProcessingFailureStage? {
    get { failureStageRawValue.flatMap(DeviceProcessingFailureStage.init(rawValue:)) }
    set { failureStageRawValue = newValue?.rawValue }
  }

  var canProcess: Bool {
    state != .processing && state != .completed
  }

  func begin(statusId: Int, statusName: String) {
    state = .processing
    failureStage = nil
    operationMessage = "Preparing"
    errorMessage = nil
    targetStatusId = statusId
    targetStatusName = statusName
  }

  func fail(stage: DeviceProcessingFailureStage, error: any Error) {
    state = .failed
    failureStage = stage
    operationMessage = nil
    errorMessage = error.localizedDescription
  }

  func complete() {
    state = .completed
    failureStage = nil
    operationMessage = nil
    errorMessage = nil
  }

  func prepareForRetry() {
    guard state != .processing else { return }
    state = .ready
    failureStage = nil
    operationMessage = nil
    errorMessage = nil
  }
}
