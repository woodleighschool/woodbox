//
//  DeviceNameMatcher.swift
//  WoodBox
//
//  Created by Alexander Hyde on 13/5/2026.
//

import Foundation

enum DeviceNameMatcher {
  static func matches(_ name: String?, pattern: String) -> Bool {
    guard let name, !name.isEmpty, !pattern.isEmpty else { return false }
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }

    let range = NSRange(name.startIndex ..< name.endIndex, in: name)
    return regex.firstMatch(in: name, range: range) != nil
  }
}
