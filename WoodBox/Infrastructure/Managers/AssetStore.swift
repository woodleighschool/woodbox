import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AssetStore {
  // MARK: - Types

  enum Status: Equatable {
    case syncing(message: String)
    case synced(date: Date?)
    case failed(message: String, date: Date?)
  }

  static let automaticSyncInterval: TimeInterval = 5 * 60

  // MARK: - Properties

  var status: Status = .synced(date: nil)

  var isSyncing: Bool {
    if case .syncing = status {
      return true
    }
    return false
  }

  @ObservationIgnored
  var lastSyncDate: Date? {
    get { defaults.object(forKey: "LastSyncDate") as? Date }
    set { defaults.set(newValue, forKey: "LastSyncDate") }
  }

  private let modelContext: ModelContext
  private let defaults: UserDefaults
  private let fetchSnapshot: () async throws -> Snapshot
  @ObservationIgnored private var syncTask: Task<Void, Never>?

  // MARK: - Init

  init(
    modelContext: ModelContext,
    defaults: UserDefaults = .standard,
    fetchSnapshot: @escaping () async throws -> Snapshot = { try await Snapshot.fetch() }
  ) {
    self.modelContext = modelContext
    self.defaults = defaults
    self.fetchSnapshot = fetchSnapshot
    status = .synced(date: lastSyncDate)
  }

  // MARK: - Public Methods

  func syncIfNeeded(now: Date = .now) async {
    guard Self.shouldAutomaticallySync(lastSyncDate: lastSyncDate, now: now) else { return }
    await sync()
  }

  func sync() async {
    if let syncTask {
      await syncTask.value
      return
    }

    // Refresh belongs to the cache, not to whichever view first requested it.
    let task = Task {
      status = .syncing(message: "Syncing…")
      do {
        let snapshot = try await fetchSnapshot()
        try process(snapshot)
        markAsSynced()
      } catch {
        modelContext.rollback()
        status = .failed(message: error.localizedDescription, date: lastSyncDate)
      }
      syncTask = nil
    }
    syncTask = task
    await task.value
  }

  func purgeAllDeviceData() async {
    await syncTask?.value
    status = .syncing(message: "Purging...")

    do {
      try process(Snapshot())
      markAsSynced()
    } catch {
      status = .failed(message: error.localizedDescription, date: Date())
    }
  }

  static func shouldAutomaticallySync(lastSyncDate: Date?, now: Date) -> Bool {
    guard let lastSyncDate else { return true }
    return now.timeIntervalSince(lastSyncDate) >= automaticSyncInterval
  }

  // MARK: - Fetchers

  struct Snapshot {
    var assets: [SnipeItAssetResponse] = []
    static func fetch(settings: AppSettings = .shared) async throws -> Self {
      guard settings.snipeItIsEnabled else { return Self() }
      let snipe = try configured(settings.configuredSnipeItClient, "Snipe-IT")
      return try await Self(assets: snipe.fetchSnipeItAssets())
    }

    private static func configured<Client>(_ client: Client?, _ integration: String) throws -> Client {
      guard let client else {
        throw IntegrationError(
          action: "refresh cache",
          integration: integration,
          message: "Required settings are missing"
        )
      }
      return client
    }
  }

  // MARK: - Processing

  private func process(_ snapshot: Snapshot) throws {
    let existingDevices = try modelContext.fetch(FetchDescriptor<Device>())
    var deviceMap = Dictionary(uniqueKeysWithValues: existingDevices.compactMap { device in
      device.snipeItId.map { ($0, device) }
    })

    for asset in snapshot.assets {
      let serial = asset.serial

      let device: Device
      if let existing = deviceMap[asset.id] {
        device = existing
      } else {
        device = Device(serial: serial, assetTag: asset.assetTag, model: asset.model.name)
        modelContext.insert(device)
        deviceMap[asset.id] = device
      }

      device.update(from: asset)
    }

    // Restock and Sale lists show their own copy of a device's details, which follows the cache.
    let devicesBySerial = Dictionary(grouping: Array(deviceMap.values), by: \.serial)
    for item in try modelContext.fetch(FetchDescriptor<DeviceProcessingItem>()) {
      if let matches = devicesBySerial[item.serial], matches.count == 1, let device = matches.first {
        item.update(from: device)
      }
    }

    let activeIds = Set(snapshot.assets.map(\.id))
    for device in existingDevices where device.snipeItId.map({ !activeIds.contains($0) }) ?? true {
      modelContext.delete(device)
    }
    try modelContext.save()
  }

  // MARK: - Helpers

  private func markAsSynced() {
    let now = Date()
    lastSyncDate = now
    status = .synced(date: now)
  }
}
