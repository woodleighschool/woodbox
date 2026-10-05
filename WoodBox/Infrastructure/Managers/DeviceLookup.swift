import Foundation
import SwiftData

extension ModelContext {
  func fetchDevice(serial: String) -> Device? {
    var descriptor = FetchDescriptor<Device>(predicate: #Predicate { $0.serial == serial })
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
