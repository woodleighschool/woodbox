import Foundation

// MARK: Pages

/// Response
nonisolated struct IntunePage<Value: Decodable>: Decodable {
  let value: [Value]
  let nextLink: String?

  enum CodingKeys: String, CodingKey {
    case nextLink = "@odata.nextLink"
    case value
  }
}

// MARK: Devices

nonisolated struct IntuneDevice: Decodable {
  let id: String
  let deviceName: String?
  let serialNumber: String
  let lastSyncDateTime: String?
  let model: String?
}

// MARK: Automated Device Enrollment

/// An enrollment program token, which Graph calls a DEP onboarding setting.
nonisolated struct IntuneEnrollmentToken: Decodable {
  let id: String
  /// Display-only relationships, requested with $expand.
  let defaultTvOSEnrollmentProfile: IntuneEnrollmentProfile?
  let defaultVisionOSEnrollmentProfile: IntuneEnrollmentProfile?
}

nonisolated struct IntuneEnrollmentProfile: Decodable {
  let id: String
  let displayName: String?
  let odataType: String?

  enum CodingKeys: String, CodingKey {
    case displayName
    case id
    case odataType = "@odata.type"
  }
}

/// A device synced from Apple School Manager or Apple Business Manager.
nonisolated struct IntuneEnrollmentDevice: Decodable {
  let serialNumber: String?
  let platform: String?
  let requestedEnrollmentProfileId: String?
  let isDeleted: Bool?
  let description: String?
}

/// Request
nonisolated struct IntuneProfileAssignmentRequest: Encodable {
  /// Serial numbers, not object IDs.
  let deviceIds: [String]
}
