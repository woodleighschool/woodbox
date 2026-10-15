import Foundation

nonisolated enum OperationActivity: Equatable {
  case waiting
  case working(String)
  case applied
  case unchanged
  case skipped(String)
  case failed(String)
}
