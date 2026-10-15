import Foundation
import Testing
@testable import WoodBox

@Suite("Enrollment workflow")
@MainActor
struct EnrollmentWorkflowTests {
  private let policy = EnrollmentPolicy(id: "policy-1", tokenId: "token-1", name: "Test Policy", platform: .macOS)

  @Test("refresh updates remote assignments while preserving the working selection")
  func preservesQueue() async {
    let service = EnrollmentFake()
    service.snapshot = snapshot(policyId: nil)
    let queue = EnrollmentQueue(service: service)
    await queue.refresh()
    #expect(queue.add(serial: "SERIAL-1") == .added)
    queue.targetPolicyId = policy.id
    service.snapshot = snapshot(policyId: policy.id)
    await queue.refresh()
    #expect(service.fetches == 2)
    #expect(queue.serials == ["SERIAL-1"])
    #expect(queue.snapshot?.devices["SERIAL-1"]?.policyId == policy.id)
    #expect(queue.targetPolicy == policy)
  }

  @Test("a failed refresh preserves the selection and its last known data")
  func retainsQueueOnFailure() async {
    let service = EnrollmentFake()
    service.snapshot = snapshot(policyId: nil)
    let queue = EnrollmentQueue(service: service)
    await queue.refresh()
    _ = queue.add(serial: "SERIAL-1")
    service.error = URLError(.timedOut)
    await queue.refresh()
    #expect(queue.serials == ["SERIAL-1"])
    #expect(queue.snapshot != nil)
    #expect(queue.loadState.failure != nil)
  }

  @Test("assignment decisions use a fresh service read, not the displayed snapshot")
  func freshAssignment() async throws {
    let service = EnrollmentFake()
    let old = snapshot(policyId: policy.id)
    service.snapshot = snapshot(policyId: nil)
    let plan = EnrollmentAssignmentPlan(serials: ["SERIAL-1", "SERIAL-1"], target: policy, snapshot: old)
    #expect(plan.batches.isEmpty)
    var activities: [String: OperationActivity] = [:]
    try await EnrollmentCoordinator(service: service).assign(plan) { activities[$0] = $1 }
    #expect(service.assignments == [["SERIAL-1"]])
    #expect(activities["SERIAL-1"] == .applied)
  }

  @Test("reopening replaces a cancelled load without letting it reset the new snapshot")
  func replacesCancelledRefresh() async {
    let service = EnrollmentFake()
    let (started, continuation) = AsyncStream<Void>.makeStream()
    var finishFirst: CheckedContinuation<EnrollmentSnapshot, Never>?
    service.fetch = {
      if service.fetches == 1 {
        return await withCheckedContinuation { finishFirst = $0; continuation.yield(()) }
      }
      return snapshot(policyId: policy.id)
    }
    let queue = EnrollmentQueue(service: service)
    let first = Task { await queue.refresh() }
    var iterator = started.makeAsyncIterator()
    await iterator.next()
    first.cancel()
    await queue.refresh()
    finishFirst?.resume(returning: snapshot(policyId: nil))
    await first.value
    #expect(service.fetches == 2)
    #expect(queue.snapshot?.devices["SERIAL-1"]?.policyId == policy.id)
    #expect(queue.loadState == .loaded)
  }

  @Test("a device already assigned remotely is skipped on retry")
  func retryUsesCurrentAssignment() async throws {
    let service = EnrollmentFake()
    service.snapshot = snapshot(policyId: policy.id)
    let plan = EnrollmentAssignmentPlan(serials: ["SERIAL-1"], target: policy, snapshot: snapshot(policyId: nil))
    var result: OperationActivity?
    try await EnrollmentCoordinator(service: service).assign(plan) { _, activity in result = activity }
    #expect(service.assignments.isEmpty)
    #expect(result == .unchanged)
  }

  @Test("a destination that becomes display-only is cleared and cannot be assigned by an open plan")
  func rejectsDisplayOnlyDestination() async throws {
    let service = EnrollmentFake()
    let original = snapshot(policyId: nil)
    service.snapshot = original
    let queue = EnrollmentQueue(service: service)
    await queue.refresh()
    _ = queue.add(serial: "SERIAL-1")
    queue.targetPolicyId = policy.id
    let plan = EnrollmentAssignmentPlan(serials: queue.serials, target: policy, snapshot: original)

    var displayOnly = policy
    displayOnly.isAssignable = false
    service.snapshot = EnrollmentSnapshot(policies: [displayOnly], devices: Array(original.devices.values))
    await queue.refresh()

    #expect(queue.targetPolicyId == nil)
    #expect(queue.targetPolicy == nil)
    #expect(queue.serials == ["SERIAL-1"])
    var result: OperationActivity?
    try await EnrollmentCoordinator(service: service).assign(plan) { _, activity in result = activity }
    #expect(service.assignments.isEmpty)
    #expect(result == .skipped("Policy does not support assignment"))
  }

  private func snapshot(policyId: String?) -> EnrollmentSnapshot {
    EnrollmentSnapshot(policies: [policy], devices: [
      EnrollmentDevice(serial: "SERIAL-1", tokenId: "token-1", platform: .macOS, policyId: policyId, summary: nil),
    ])
  }
}

@MainActor
private final class EnrollmentFake: EnrollmentServicing {
  var snapshot = EnrollmentSnapshot(policies: [], devices: [])
  var error: Error?
  var fetches = 0
  var assignments: [[String]] = []
  var fetch: (() async throws -> EnrollmentSnapshot)?

  func fetchSnapshot() async throws -> EnrollmentSnapshot {
    fetches += 1
    if let fetch {
      return try await fetch()
    }
    if let error {
      throw error
    }
    return snapshot
  }

  func assign(_: EnrollmentPolicy, serials: [String]) async throws {
    assignments.append(serials)
  }
}
