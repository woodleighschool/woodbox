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
