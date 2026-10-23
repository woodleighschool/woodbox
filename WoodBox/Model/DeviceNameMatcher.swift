import Foundation

enum DeviceNameMatcher {
  static func matches(_ name: String?, pattern: String) -> Bool {
    guard let name, !name.isEmpty, !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern) else { return false }

    let range = NSRange(name.startIndex ..< name.endIndex, in: name)
    return regex.firstMatch(in: name, range: range) != nil
  }
}
