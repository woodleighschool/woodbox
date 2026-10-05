import Foundation
import SwiftData
import Testing
@testable import WoodBox

@Suite("Cache refresh completion")
@MainActor
struct CacheManagerTests {
  @Test("overlapping refreshes both wait until one snapshot has been saved")
  func joinsRefreshThroughPersistence() async throws {
    let schema = Schema([Device.self, MDMRecord.self, SnipeItUser.self, SnipeItStatus.self])
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.insert(Device(serial: "OLD1234567", assetTag: "OLD", model: "Old Laptop"))
    try context.save()

    let suite = "CacheManagerTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let loader = DeferredSnapshot()
    let manager = CacheManager(modelContext: context, defaults: defaults, fetchSnapshot: loader.load)
    var completed = 0
    let first = Task { await manager.sync(); completed += 1 }
    var started = loader.started.makeAsyncIterator()
    await started.next()

    let (joined, joinContinuation) = AsyncStream<Void>.makeStream()
    let second = Task {
      joinContinuation.yield(())
      await manager.sync()
      completed += 1
    }
    var joining = joined.makeAsyncIterator()
    await joining.next()
    #expect(completed == 0)
    #expect(manager.isSyncing)
    #expect(loader.calls == 1)

    let asset = try JSONDecoder().decode(SnipeItAssetResponse.self, from: Data(#"{"id":7,"asset_tag":"TEST-7","serial":"TEST123456","model":{"name":"Test Laptop"},"status_label":{"id":2,"name":"Shelf"}}"#.utf8))
    loader.finish(.success(CacheManager.Snapshot(assets: [asset])))
    await first.value
    await second.value

    #expect(completed == 2)
    #expect(!manager.isSyncing)
    let persisted = try ModelContext(container).fetch(FetchDescriptor<Device>())
    #expect(persisted.map(\.serial) == ["TEST123456"])
    #expect(persisted.first?.status == "Shelf")
    #expect(manager.lastSyncDate != nil)
  }

  @Test("a failed fetch retains the cache and allows another refresh")
  func retriesAfterFailure() async throws {
    let schema = Schema([Device.self, MDMRecord.self, SnipeItUser.self, SnipeItStatus.self])
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.insert(Device(serial: "OLD1234567", assetTag: "OLD", model: "Old Laptop"))
    try context.save()
    let suite = "CacheManagerTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    var calls = 0
    let manager = CacheManager(modelContext: context, defaults: defaults) {
      calls += 1
      if calls == 1 {
        throw URLError(.timedOut)
      }
      return CacheManager.Snapshot()
    }
    await manager.sync()
    #expect(!manager.isSyncing)
    #expect(manager.lastSyncDate == nil)
    #expect(try context.fetchCount(FetchDescriptor<Device>()) == 1)
    await manager.sync()
    #expect(calls == 2)
    #expect(try context.fetchCount(FetchDescriptor<Device>()) == 0)
  }

  @Test("post-mutation refresh fetches again after any older snapshot")
  func refreshesAfterChanges() async throws {
    let schema = Schema([Device.self, MDMRecord.self, SnipeItUser.self, SnipeItStatus.self])
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let suite = "CacheManagerTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let loader = DeferredSnapshot()
    let manager = CacheManager(modelContext: ModelContext(container), defaults: defaults, fetchSnapshot: loader.load)
    let older = Task { await manager.sync() }
    var started = loader.started.makeAsyncIterator()
    await started.next()

    var completed = false
    let (joined, continuation) = AsyncStream<Void>.makeStream()
    let afterChanges = Task {
      continuation.yield(())
      await manager.syncAfterChanges()
      completed = true
    }
    var joining = joined.makeAsyncIterator()
    await joining.next()
    loader.finish(.success(CacheManager.Snapshot()))
    await started.next()
    #expect(loader.calls == 2)
    #expect(!completed)
    loader.finish(.success(CacheManager.Snapshot()))
    await older.value
    await afterChanges.value
    #expect(completed)
  }
}

@MainActor
private final class DeferredSnapshot {
  let started: AsyncStream<Void>
  private let startedContinuation: AsyncStream<Void>.Continuation
  private var continuation: CheckedContinuation<CacheManager.Snapshot, any Error>?
  private(set) var calls = 0

  init() {
    (started, startedContinuation) = AsyncStream.makeStream()
  }

  func load() async throws -> CacheManager.Snapshot {
    calls += 1
    return try await withCheckedThrowingContinuation {
      continuation = $0
      startedContinuation.yield(())
    }
  }

  func finish(_ result: Result<CacheManager.Snapshot, any Error>) {
    continuation?.resume(with: result)
    continuation = nil
  }
}
