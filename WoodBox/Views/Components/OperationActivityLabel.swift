import SwiftUI

struct OperationActivityLabel: View {
  let activity: OperationActivity

  @State private var showsDetails = false

  var body: some View {
    Group {
      switch activity {
      case .waiting:
        Image(systemName: "clock.fill")
          .help("Waiting")
      case let .working(message):
        ProgressView()
          .controlSize(.small)
          .help(message)
      case .applied:
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .help("Applied")
      case .unchanged:
        Image(systemName: "checkmark.circle.fill")
          .help("Already Applied")
      case let .skipped(reason):
        detailsButton("Skipped", message: reason, symbol: "minus.circle.fill")
      case let .failed(message):
        detailsButton("Failed", message: message, symbol: "exclamationmark.circle.fill")
          .foregroundStyle(.red)
      }
    }
    .font(.title3)
    .foregroundStyle(.secondary)
    .frame(width: 28)
  }

  private func detailsButton(_ title: String, message: String, symbol: String) -> some View {
    Button {
      showsDetails = true
    } label: {
      Image(systemName: symbol)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .help(message)
    .alert(title, isPresented: $showsDetails) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(message)
    }
  }
}
