import Foundation

// MARK: Check-In Asset

/// Request
struct SnipeItCheckinRequest: Encodable {
  let statusId: Int
  let name: String?
  let note: String?
  let locationId: String?

  private enum CodingKeys: String, CodingKey {
    case locationId = "location_id"
    case name
    case note
    case statusId = "status_id"
  }
}

// MARK: Check-Out Asset

/// Request
struct SnipeItCheckoutRequest: Encodable {
  let checkoutToType = "user"
  let assignedUser: Int
  let statusId: Int
  let note: String?

  private enum CodingKeys: String, CodingKey {
    case checkoutToType = "checkout_to_type"
    case assignedUser = "assigned_user"
    case statusId = "status_id"
    case note
  }
}

// MARK: Users

/// Response
struct SnipeItUsersResponse: Decodable {
  let rows: [SnipeItUserResponse]
}

struct SnipeItUserResponse: Decodable {
  let id: Int
  let name: String?
  let email: String?
}

// MARK: Statuses

/// Response
struct SnipeItStatusesResponse: Decodable {
  let rows: [SnipeItStatusResponse]
}

struct SnipeItStatusResponse: Decodable {
  let id: Int
  let name: String
}

// MARK: Update Asset

/// Request
struct SnipeItUpdateRequest: Encodable {
  let statusId: Int?
  let notes: String?
  let customFields: [String: String]?

  private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? {
      nil
    }

    init(stringValue: String) {
      self.stringValue = stringValue
    }

    init?(intValue _: Int) {
      nil
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicKey.self)
    try container.encodeIfPresent(statusId, forKey: .init(stringValue: "status_id"))
    try container.encodeIfPresent(notes, forKey: .init(stringValue: "notes"))
    if let customFields {
      for (key, value) in customFields {
        try container.encode(value, forKey: .init(stringValue: key))
      }
    }
  }
}

// MARK: Assets

/// Response
struct SnipeItAssetsResponse: Decodable {
  let rows: [SnipeItAssetResponse]
}

struct SnipeItAssetResponse: Decodable {
  let id: Int
  let name: String?
  let assetTag: String
  let serial: String
  let model: SnipeItAssetModel
  let category: SnipeItAssetCategory?
  let statusLabel: SnipeItAssetStatus?
  let assignedTo: SnipeItAssetUser?
  let notes: String?
  let customFields: [String: SnipeItAssetCustomField]?
  let warrantyExpires: SnipeItWarrantyDate?

  private enum CodingKeys: String, CodingKey {
    case assetTag = "asset_tag"
    case assignedTo = "assigned_to"
    case category
    case customFields = "custom_fields"
    case id
    case model
    case name
    case notes
    case serial
    case statusLabel = "status_label"
    case warrantyExpires = "warranty_expires"
  }

  subscript(customField key: String) -> String? {
    customFields?[key]?.value
  }
}

struct SnipeItAssetCustomField: Decodable {
  let field: String
  let value: String?

  private enum CodingKeys: String, CodingKey {
    case field
    case value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    field = try container.decode(String.self, forKey: .field)
    value = try container.decodeIfPresent(String.self, forKey: .value).nilIfEmpty
  }
}

struct SnipeItWarrantyDate: Decodable {
  let date: String?
}

struct SnipeItAssetModel: Decodable {
  let name: String
}

struct SnipeItAssetCategory: Decodable {
  let name: String
}

struct SnipeItAssetStatus: Decodable {
  let id: Int
  let name: String
}

struct SnipeItAssetUser: Decodable {
  let name: String
  let email: String?
}
