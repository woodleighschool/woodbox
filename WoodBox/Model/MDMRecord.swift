import Foundation

nonisolated struct MDMRecord: Identifiable, Equatable, Sendable {
  let provider: MDMProvider
  let deviceId: String
  let serial: String
  let deviceName: String?
  let lastCheckIn: Date?
  let jamfDeviceType: JamfDeviceType?
  var model: String?

  /// Jamf computer and mobile record IDs occupy separate namespaces.
  var id: String {
    "\(provider.rawValue)-\(jamfDeviceType?.rawValue ?? "na")-\(deviceId)"
  }
}

nonisolated enum MDMProvider: String, CaseIterable, Identifiable, Sendable {
  case jamf = "Jamf"
  case intune = "Intune"

  var id: Self {
    self
  }
}

nonisolated enum JamfDeviceType: String, Sendable {
  case computer = "Computer"
  case mobile = "Mobile"
}

nonisolated struct DuplicateGroup: Identifiable, Equatable {
  let serial: String
  let records: [MDMRecord]

  var id: String {
    serial
  }

  static func groups(in records: [MDMRecord]) -> [Self] {
    let identifiable = records.filter { !$0.serial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    return Dictionary(grouping: identifiable, by: { $0.serial.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })
      .compactMap { serial, records in
        let unique = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        guard unique.count > 1 else { return nil }
        return Self(serial: serial, records: unique.sorted {
          if $0.lastCheckIn != $1.lastCheckIn {
            return ($0.lastCheckIn ?? .distantPast) > ($1.lastCheckIn ?? .distantPast)
          }
          return $0.id < $1.id
        })
      }
      .sorted { $0.serial < $1.serial }
  }
}
