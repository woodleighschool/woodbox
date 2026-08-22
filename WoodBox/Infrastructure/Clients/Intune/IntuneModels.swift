import Foundation

// MARK: Devices

/// Response
struct IntuneDevicePageResponse: Decodable {
  let value: [IntuneDevice]
  let nextLink: String?

  enum CodingKeys: String, CodingKey {
    case nextLink = "@odata.nextLink"
    case value
  }
}

struct IntuneDevice: Decodable {
  let id: String
  let deviceName: String?
  let serialNumber: String
  let lastSyncDateTime: String?
}
