extension String {
  /// Returns `nil` if the string is empty, otherwise returns `self`.
  nonisolated var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

extension String? {
  /// Returns `nil` if the string is nil or empty, otherwise returns the wrapped value.
  nonisolated var nilIfEmpty: String? {
    self?.nilIfEmpty
  }
}
