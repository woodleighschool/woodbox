import Testing
@testable import WoodBox

@Suite("Refresh failure alerts")
@MainActor
struct RefreshFailurePolicyTests {
  @Test("repeated automatic failures stay quiet until a refresh succeeds")
  func suppressesRepeatedAutomaticFailures() {
    let policy = RefreshFailurePolicy()
    let failure = LoadState.failed("The service is unavailable.")

    #expect(policy.message(for: failure, userInitiated: false) == failure.failure)
    #expect(policy.message(for: .loading, userInitiated: false) == nil)
    #expect(policy.message(for: .idle, userInitiated: false) == nil)
    #expect(policy.message(for: failure, userInitiated: false) == nil)
    #expect(policy.message(for: .loaded, userInitiated: false) == nil)
    #expect(policy.message(for: failure, userInitiated: false) == failure.failure)
  }

  @Test("explicit retries report failures while automatic attempts stay quiet")
  func reportsNewOutcomes() {
    let policy = RefreshFailurePolicy()
    let unavailable = LoadState.failed("The service is unavailable.")
    let rejected = LoadState.failed("The credentials were rejected.")

    #expect(policy.message(for: unavailable, userInitiated: false) == unavailable.failure)
    #expect(policy.message(for: unavailable, userInitiated: true) == unavailable.failure)
    #expect(policy.message(for: unavailable, userInitiated: false) == nil)
    #expect(policy.message(for: rejected, userInitiated: false) == nil)
    #expect(policy.message(for: rejected, userInitiated: true) == rejected.failure)
  }

  @Test("another refresh source cannot clear an outstanding failure")
  func keepsSourcesIndependent() {
    let assets = RefreshFailurePolicy()
    let mdm = RefreshFailurePolicy()
    let failure = LoadState.failed("The service is unavailable.")

    #expect(assets.message(for: failure, userInitiated: false) == failure.failure)
    #expect(mdm.message(for: .loaded, userInitiated: false) == nil)
    #expect(assets.message(for: failure, userInitiated: false) == nil)
  }
}
