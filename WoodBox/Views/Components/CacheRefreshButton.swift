import SwiftUI

struct CacheRefreshButton: View {
  @Environment(ModelData.self) private var modelData

  @State private var failureMessage = ""
  @State private var isFailurePresented = false

  private var cacheManager: CacheManager {
    modelData.cacheManager
  }

  var body: some View {
    Button {
      Task { await refresh() }
    } label: {
      if cacheManager.isSyncing {
        ProgressView()
          .controlSize(.small)
      } else {
        Label("Refresh Cache", systemImage: symbolName)
      }
    }
    .disabled(cacheManager.isSyncing || modelData.settings.snipeItIsEnabled == false)
    .help(helpText)
    .keyboardShortcut("r")
    .accessibilityLabel("Refresh Cache")
    .accessibilityValue(accessibilityValue)
    .alert("Cache Refresh Failed", isPresented: $isFailurePresented) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(failureMessage)
    }
  }

  private var symbolName: String {
    if case .failed = cacheManager.status {
      "exclamationmark.triangle"
    } else {
      "arrow.clockwise"
    }
  }

  private var helpText: String {
    if modelData.settings.snipeItIsEnabled == false {
      return "Enable Snipe-IT to refresh the cache"
    }

    switch cacheManager.status {
    case let .syncing(message):
      return message
    case let .synced(date):
      guard let date else { return "Refresh cache" }
      return "Last refreshed \(date.formatted(date: .abbreviated, time: .shortened))"
    case let .failed(message, _):
      return message
    }
  }

  private var accessibilityValue: String {
    switch cacheManager.status {
    case let .syncing(message):
      message
    case .synced:
      "Ready"
    case let .failed(message, _):
      "Failed: \(message)"
    }
  }

  @MainActor
  private func refresh() async {
    await cacheManager.sync()

    if case let .failed(message, _) = cacheManager.status {
      failureMessage = message
      isFailurePresented = true
    }
  }
}
