import Foundation

nonisolated enum LoadState: Equatable {
  case idle
  case loading
  case loaded
  case failed(String)

  var isLoading: Bool {
    self == .loading
  }

  var failure: String? {
    if case let .failed(message) = self {
      message
    } else {
      nil
    }
  }
}

@MainActor
final class RefreshFailurePolicy {
  private var hasReportedFailure = false

  func message(for state: LoadState, userInitiated: Bool) -> String? {
    if state == .loaded {
      hasReportedFailure = false
    }
    guard let message = state.failure else { return nil }
    defer { hasReportedFailure = true }
    return userInitiated || !hasReportedFailure ? message : nil
  }
}
