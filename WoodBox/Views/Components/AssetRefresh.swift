import SwiftUI

extension View {
  func assetRefreshable() -> some View {
    modifier(AssetRefreshModifier())
  }
}

private struct AssetRefreshModifier: ViewModifier {
  @Environment(ModelData.self) private var modelData

  private var state: LoadState {
    switch modelData.assetStore.status {
    case .syncing: .loading
    case .synced: .loaded
    case let .failed(message, _): .failed(message)
    }
  }

  func body(content: Content) -> some View {
    content.toolRefreshable(
      state: state,
      failurePolicy: modelData.snipeRefreshFailures,
      title: "Refresh Assets",
      disabled: !modelData.settings.snipeItIsEnabled
    ) { userInitiated in
      let previousSyncDate = modelData.assetStore.lastSyncDate
      if userInitiated {
        await modelData.assetStore.sync()
      } else {
        await modelData.assetStore.syncIfNeeded()
      }
      // Keeping a recent cache does not establish that the service has recovered.
      if !userInitiated, state == .loaded, previousSyncDate == modelData.assetStore.lastSyncDate {
        return .idle
      }
      return state
    }
  }
}
