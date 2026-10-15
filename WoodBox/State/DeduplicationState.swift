import Foundation

@Observable
@MainActor
final class DeduplicationState {
  private(set) var records: [MDMRecord] = []
  private(set) var loadState = LoadState.idle
  private var refreshID = UUID()
  private(set) var hasLoaded = false
  private(set) var deleting: Set<String> = []

  private let fetchRecords: () async throws -> [MDMRecord]
  private let deleteRecord: (MDMDeletionService.Request) async throws -> Void

  init(
    fetchRecords: @escaping () async throws -> [MDMRecord],
    deleteRecord: @escaping (MDMDeletionService.Request) async throws -> Void = { try await MDMDeletionService.delete($0) }
  ) {
    self.fetchRecords = fetchRecords
    self.deleteRecord = deleteRecord
  }

  var groups: [DuplicateGroup] {
    DuplicateGroup.groups(in: records)
  }

  func refresh() async {
    guard deleting.isEmpty else { return }
    let id = UUID()
    refreshID = id
    loadState = .loading
    do {
      let fetched = try await fetchRecords()
      try Task.checkCancellation()
      guard refreshID == id else { return }
      records = fetched
      hasLoaded = true
      loadState = .loaded
    } catch {
      guard refreshID == id else { return }
      loadState = Task.isCancelled ? (hasLoaded ? .loaded : .idle) : .failed(error.localizedDescription)
    }
  }

  func delete(_ record: MDMRecord) async throws {
    guard !loadState.isLoading, deleting.insert(record.id).inserted else { return }
    defer { deleting.remove(record.id) }
    try await deleteRecord(MDMDeletionService.Request(record: record))
    records.removeAll { $0.id == record.id }
  }
}
