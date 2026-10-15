import Foundation

@Observable
@MainActor
final class SnipeITReferenceData {
  private(set) var statuses: [SnipeItStatusResponse] = []
  private(set) var loadState = LoadState.idle
  private var refreshID = UUID()
  private let settings: AppSettings

  init(settings: AppSettings) {
    self.settings = settings
  }

  func refresh() async {
    let id = UUID()
    refreshID = id
    loadState = .loading
    do {
      guard let client = settings.snipeItClient else {
        throw IntegrationError(action: "load statuses", integration: "Snipe-IT", message: "The integration is not enabled or configured")
      }
      let fetched = try await client.fetchSnipeItStatuses()
      try Task.checkCancellation()
      guard refreshID == id else { return }
      statuses = fetched.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      loadState = .loaded
    } catch {
      guard refreshID == id else { return }
      loadState = Task.isCancelled ? .idle : .failed(error.localizedDescription)
    }
  }
}
