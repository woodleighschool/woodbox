import Foundation
import Testing
@testable import WoodBox

@Suite("Cache refresh policy")
@MainActor
struct CacheRefreshPolicyTests {
  @Test("refreshes missing and stale caches without refreshing a recent cache")
  func refreshesWhenNeeded() {
    let now = Date(timeIntervalSinceReferenceDate: 1000)

    #expect(AssetStore.shouldAutomaticallySync(lastSyncDate: nil, now: now))
    #expect(
      AssetStore.shouldAutomaticallySync(
        lastSyncDate: now.addingTimeInterval(-AssetStore.automaticSyncInterval),
        now: now
      )
    )
    #expect(
      AssetStore.shouldAutomaticallySync(
        lastSyncDate: now.addingTimeInterval(-(AssetStore.automaticSyncInterval - 1)),
        now: now
      ) == false
    )
  }
}
