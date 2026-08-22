import Foundation
import Testing
@testable import WoodBox

@Suite("Cache refresh policy")
@MainActor
struct CacheRefreshPolicyTests {
  @Test("refreshes missing and stale caches without refreshing a recent cache")
  func refreshesWhenNeeded() {
    let now = Date(timeIntervalSinceReferenceDate: 1000)

    #expect(CacheManager.shouldAutomaticallySync(lastSyncDate: nil, now: now))
    #expect(
      CacheManager.shouldAutomaticallySync(
        lastSyncDate: now.addingTimeInterval(-CacheManager.automaticSyncInterval),
        now: now
      )
    )
    #expect(
      CacheManager.shouldAutomaticallySync(
        lastSyncDate: now.addingTimeInterval(-(CacheManager.automaticSyncInterval - 1)),
        now: now
      ) == false
    )
  }
}
