import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class CacheManager {
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
  private let settings = AppSettings.shared
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
        status = .failed(message: error.localizedDescription, date: Date())
      }
      syncTask = nil
    }
    syncTask = task
    await task.value
  }

  func syncAfterChanges() async {
    // A snapshot requested before a mutation cannot confirm its outcome.
    await syncTask?.value
    await sync()
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

  func removeMDMRecords(for providers: Set<MDMProvider>) async {
    await syncTask?.value
    guard settings.snipeItIsEnabled else { return }
    status = .syncing(message: "Updating Records...")

    do {
      let devices = try modelContext.fetch(FetchDescriptor<Device>())
      for device in devices {
        let toRemove = device.mdmRecords.filter { providers.contains($0.provider) }
        for record in toRemove {
          modelContext.delete(record)
        }
        device.mdmRecords = device.mdmRecords.filter { !providers.contains($0.provider) }
      }
      try modelContext.save()
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
    var users: [SnipeItUserResponse] = []
    var statuses: [SnipeItStatusResponse] = []
    var computers: [JamfComputer] = []
    var mobiles: [JamfMobileDevice] = []
    var intuneDevices: [IntuneDevice] = []

    static func fetch() async throws -> Self {
      let settings = AppSettings.shared
      guard settings.snipeItIsEnabled else { return Self() }
      let snipe = try configured(settings.configuredSnipeItClient, "Snipe-IT")
      // An enabled provider has to take part. Leaving it out would drop its records from the cache.
      let jamf = settings.jamfIsEnabled ? try configured(settings.configuredJamfClient, "Jamf") : nil
      let intune = settings.intuneIsEnabled
        ? try configured(settings.configuredIntuneClient, "Intune")
        : nil

      async let assets = snipe.fetchSnipeItAssets()
      async let users = snipe.fetchSnipeItUsers()
      async let statuses = snipe.fetchSnipeItStatuses()
      async let computers = jamf?.fetchJamfComputers() ?? []
      async let mobiles = jamf?.fetchJamfMobileDevices() ?? []
      async let intuneDevices = intune?.fetchIntuneDevices() ?? []
      return try await Self(
        assets: assets, users: users, statuses: statuses,
        computers: computers, mobiles: mobiles, intuneDevices: intuneDevices
      )
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
    try processUsers(snapshot.users)
    try processStatuses(snapshot.statuses)
    let jamfComputerMap = Dictionary(grouping: snapshot.computers, by: \.hardware.serialNumber)
    let jamfMobileMap = Dictionary(grouping: snapshot.mobiles, by: \.hardware.serialNumber)
    let intuneMap = Dictionary(grouping: snapshot.intuneDevices, by: \.serialNumber)

    let existingDevices = try modelContext.fetch(FetchDescriptor<Device>())
    var deviceMap = Dictionary(uniqueKeysWithValues: existingDevices.map { ($0.serial, $0) })

    for asset in snapshot.assets {
      let serial = asset.serial

      let device: Device
      if let existing = deviceMap[serial] {
        device = existing
      } else {
        device = Device(serial: serial, assetTag: asset.assetTag, model: asset.model.name)
        modelContext.insert(device)
        deviceMap[serial] = device
      }

      device.assetTag = asset.assetTag
      device.name = asset.name.nilIfEmpty
      device.model = asset.model.name
      device.category = asset.category?.name.nilIfEmpty
      device.status = asset.statusLabel?.name.nilIfEmpty
      device.statusId = asset.statusLabel?.id
      device.snipeItId = asset.id
      device.notes = asset.notes.nilIfEmpty
      device.ram = asset[customField: "RAM"]
      device.storage = asset[customField: "Storage"]
      device.assignedUserName = asset.assignedTo?.name.nilIfEmpty
      device.assignedUserEmail = asset.assignedTo?.email.nilIfEmpty
      device.warrantyExpires = asset.warrantyExpires?.date.flatMap {
        Self.dateOnlyFormatter.date(from: $0)
      }

      // Refresh MDM records
      for record in device.mdmRecords {
        modelContext.delete(record)
      }

      let jamfComputerRecords: [MDMRecord] = (jamfComputerMap[serial] ?? []).map {
        MDMRecord(
          provider: .jamf,
          deviceId: $0.id,
          deviceName: $0.general.name.nilIfEmpty,
          lastCheckIn: $0.general.lastContactTime.flatMap { try? Date($0, strategy: .iso8601) },
          jamfDeviceType: .computer,
          device: device
        )
      }

      let jamfMobileRecords: [MDMRecord] = (jamfMobileMap[serial] ?? []).map {
        MDMRecord(
          provider: .jamf,
          deviceId: $0.mobileDeviceId,
          deviceName: $0.name.nilIfEmpty,
          lastCheckIn: $0.general.lastInventoryUpdateDate.flatMap {
            try? Date($0, strategy: .iso8601)
          },
          jamfDeviceType: .mobile,
          device: device
        )
      }

      let intuneRecords: [MDMRecord] = (intuneMap[serial] ?? []).map {
        MDMRecord(
          provider: .intune,
          deviceId: $0.id,
          deviceName: $0.deviceName.nilIfEmpty,
          lastCheckIn: $0.lastSyncDateTime.flatMap { try? Date($0, strategy: .iso8601) },
          jamfDeviceType: nil,
          device: device
        )
      }

      let records = jamfComputerRecords + jamfMobileRecords + intuneRecords

      for record in records {
        modelContext.insert(record)
      }
      device.mdmRecords = records
    }

    let activeSerials = Set(snapshot.assets.map(\.serial))
    for device in existingDevices where !activeSerials.contains(device.serial) {
      modelContext.delete(device)
    }
    try modelContext.save()
  }

  // MARK: - Helpers

  private static let dateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
  }()

  private func markAsSynced() {
    let now = Date()
    lastSyncDate = now
    status = .synced(date: now)
  }

  private func processUsers(_ snipeItUsers: [SnipeItUserResponse]) throws {
    let existing = try modelContext.fetch(FetchDescriptor<SnipeItUser>())
    var userMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.snipeItId, $0) })

    for userResponse in snipeItUsers {
      if let user = userMap[userResponse.id] {
        user.name = userResponse.name.nilIfEmpty
        user.email = userResponse.email.nilIfEmpty
      } else {
        let user = SnipeItUser(
          snipeItId: userResponse.id,
          name: userResponse.name.nilIfEmpty,
          email: userResponse.email.nilIfEmpty
        )
        modelContext.insert(user)
        userMap[userResponse.id] = user
      }
    }

    let activeIds = Set(snipeItUsers.map(\.id))
    for user in existing where !activeIds.contains(user.snipeItId) {
      modelContext.delete(user)
    }
  }

  private func processStatuses(_ snipeItStatuses: [SnipeItStatusResponse]) throws {
    let existing = try modelContext.fetch(FetchDescriptor<SnipeItStatus>())
    var statusMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.snipeItId, $0) })

    for statusResponse in snipeItStatuses {
      if let status = statusMap[statusResponse.id] {
        status.name = statusResponse.name
      } else {
        let status = SnipeItStatus(snipeItId: statusResponse.id, name: statusResponse.name)
        modelContext.insert(status)
        statusMap[statusResponse.id] = status
      }
    }

    let activeIds = Set(snipeItStatuses.map(\.id))
    for status in existing where !activeIds.contains(status.snipeItId) {
      modelContext.delete(status)
    }
  }
}
