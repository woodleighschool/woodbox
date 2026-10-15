import SwiftUI

struct ToolLoadingView: View {
  let title: String
  let state: LoadState

  var body: some View {
    if let message = state.failure {
      ContentUnavailableView {
        Label("Unable to Load", systemImage: "exclamationmark.triangle")
      } description: {
        Text(message)
      }
    } else {
      #if os(macOS)
        ProgressView(title)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      #endif
    }
  }
}

extension View {
  func toolRefreshable(
    state: LoadState,
    failurePolicy: RefreshFailurePolicy,
    title: String = "Refresh",
    disabled: Bool = false,
    refresh: @escaping (_ userInitiated: Bool) async -> LoadState
  ) -> some View {
    modifier(ToolRefreshModifier(state: state, failurePolicy: failurePolicy, title: title, disabled: disabled, refresh: refresh))
  }
}

private struct ToolRefreshModifier: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase

  let state: LoadState
  let failurePolicy: RefreshFailurePolicy
  let title: String
  let disabled: Bool
  let refresh: (Bool) async -> LoadState

  @State private var requestID: UUID?
  @State private var failure: String?

  func body(content: Content) -> some View {
    content
    #if os(iOS)
      .refreshable { await run(userInitiated: true) }
      .background {
        RefreshControlPresentation(isRefreshing: state.isLoading, isEnabled: !disabled)
      }
    #else
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            Task { await run(userInitiated: true) }
          } label: {
            if state.isLoading {
              ProgressView().controlSize(.small)
            } else {
              Label(title, systemImage: "arrow.clockwise")
            }
          }
          .disabled(disabled || state.isLoading)
          .keyboardShortcut("r")
          .help(title)
        }
      }
    #endif
      .task(id: scenePhase) {
        guard scenePhase == .active else { return }
        await run(userInitiated: false)
      }
      .alert("Unable to Refresh", item: $failure) { _ in
        Button("Try Again") { Task { await run(userInitiated: true) } }
        Button("OK", role: .cancel) {}
      } message: {
        Text($0)
      }
  }

  private func run(userInitiated: Bool) async {
    guard !disabled else { return }
    if userInitiated, requestID != nil || state.isLoading {
      return
    }
    let id = UUID()
    requestID = id
    defer {
      if requestID == id {
        requestID = nil
      }
    }
    let result = await refresh(userInitiated)
    guard !Task.isCancelled, requestID == id else { return }
    if let message = failurePolicy.message(for: result, userInitiated: userInitiated) {
      failure = message
    }
  }
}
