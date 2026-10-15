import Foundation
import Testing
@testable import WoodBox

@Suite("Live deduplication")
@MainActor
struct DeduplicationTests {
  @Test("service records group without assets and never group blank serials")
  func groupsServiceRecords() {
    let computer = record("1", serial: " ab123 ")
    let mobile = MDMRecord(
      provider: .jamf,
      deviceId: "1",
      serial: "AB123",
      deviceName: nil,
      lastCheckIn: nil,
      jamfDeviceType: .mobile
    )
    let intune = record("2", serial: "AB123", provider: .intune)
    let groups = DuplicateGroup.groups(in: [computer, computer, mobile, intune, record("3", serial: ""), record("4", serial: " "), record("5", serial: "\n\t")])
    #expect(groups.count == 1)
    #expect(groups.first?.serial == "AB123")
    #expect(groups.first?.records.count == 3)
    #expect(computer.id != mobile.id)
  }

  @Test("opening again reads the service again and a failed refresh retains the last list")
  func refreshesIndependently() async {
    var calls = 0
    let initial = [record("1"), record("2")]
    let state = DeduplicationState(fetchRecords: {
      calls += 1
      if calls == 3 {
        throw URLError(.notConnectedToInternet)
      }
      return calls == 1 ? initial : initial + [record("3")]
    })
    await state.refresh()
    #expect(state.records.count == 2)
    await state.refresh()
    #expect(state.records.count == 3)
    await state.refresh()
    #expect(state.records.count == 3)
    #expect(state.loadState.failure != nil)
    #expect(calls == 3)
  }

  @Test("a failed first load is not an empty successful inventory")
  func firstFailure() async {
    let state = DeduplicationState(fetchRecords: { throw URLError(.timedOut) })
    await state.refresh()
    #expect(!state.hasLoaded)
    #expect(state.loadState.failure != nil)
  }

  @Test("reopening during a cancelled fetch starts a new load and ignores the old result")
  func replacesCancelledRefresh() async {
    let (started, continuation) = AsyncStream<Void>.makeStream()
    var finishFirst: CheckedContinuation<[MDMRecord], Never>?
    var fetches = 0
    let state = DeduplicationState(fetchRecords: {
      fetches += 1
      if fetches == 1 {
        return await withCheckedContinuation { finishFirst = $0; continuation.yield(()) }
      }
      return [record("new")]
    })
    let first = Task { await state.refresh() }
    var iterator = started.makeAsyncIterator()
    await iterator.next()
    first.cancel()
    await state.refresh()
    finishFirst?.resume(returning: [record("old")])
    await first.value
    #expect(fetches == 2)
    #expect(state.records.map(\.deviceId) == ["new"])
    #expect(state.loadState == .loaded)
  }

  @Test("deletion retains the row while pending and refresh cannot reintroduce it")
  func deletionOwnsItsResult() async throws {
    let initial = [record("1"), record("2")]
    let (started, continuation) = AsyncStream<Void>.makeStream()
    var complete: CheckedContinuation<Void, any Error>?
    var fetches = 0
    let state = DeduplicationState(fetchRecords: { fetches += 1; return initial }, deleteRecord: { _ in
      try await withCheckedThrowingContinuation { complete = $0; continuation.yield(()) }
    })
    await state.refresh()
    let deletion = Task { try await state.delete(initial[0]) }
    var iterator = started.makeAsyncIterator()
    await iterator.next()
    #expect(state.records.count == 2)
    await state.refresh()
    #expect(fetches == 1)
    complete?.resume()
    try await deletion.value
    #expect(state.records == [initial[1]])
    #expect(state.deleting.isEmpty)
  }

  @Test("failed deletion keeps the record without a local rollback")
  func failedDeletion() async {
    let initial = [record("1"), record("2")]
    let state = DeduplicationState(fetchRecords: { initial }, deleteRecord: { _ in throw URLError(.timedOut) })
    await state.refresh()
    do {
      try await state.delete(initial[0])
      Issue.record("Expected deletion to fail")
    } catch {}
    #expect(state.records == initial)
    #expect(state.deleting.isEmpty)
  }

  private func record(_ id: String, serial: String = "SERIAL-1", provider: MDMProvider = .jamf) -> MDMRecord {
    MDMRecord(
      provider: provider,
      deviceId: id,
      serial: serial,
      deviceName: nil,
      lastCheckIn: nil,
      jamfDeviceType: provider == .jamf ? .computer : nil
    )
  }
}
