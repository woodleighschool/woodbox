import Foundation
import SwiftData

nonisolated enum ScanType {
  case assetTag
  case serial

  #if os(iOS)
    var label: String {
      switch self {
      case .assetTag: "asset tag"
      case .serial: "serial number"
      }
    }
  #endif
}

extension ModelContext {
  func fetchDevice(matching value: String, scanType: ScanType) -> Device? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return nil }

    let predicate: Predicate<Device> =
      scanType == .assetTag
        ? #Predicate { $0.assetTag == normalized }
      : #Predicate { $0.serial == normalized }

    var descriptor = FetchDescriptor<Device>(predicate: predicate)
    descriptor.fetchLimit = 1
    return try? fetch(descriptor).first
  }

  func fetchDevice(matchingIdentifier value: String) -> Device? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return nil }

    var descriptor = FetchDescriptor<Device>(
      predicate: #Predicate {
        $0.assetTag == normalized || $0.serial == normalized
      }
    )
    descriptor.fetchLimit = 1
    return try? fetch(descriptor).first
  }

  func searchDevices(matching value: String, limit: Int = 25) -> [Device] {
    let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }

    var descriptor = FetchDescriptor<Device>(
      predicate: #Predicate { device in
        device.serial.localizedStandardContains(query)
          || device.assetTag.localizedStandardContains(query)
          || device.assignedUserEmail?.localizedStandardContains(query) == true
      },
      sortBy: [SortDescriptor(\Device.name)]
    )
    descriptor.fetchLimit = limit
    return (try? fetch(descriptor)) ?? []
  }
}
