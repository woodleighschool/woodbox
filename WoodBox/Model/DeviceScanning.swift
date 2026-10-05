import Foundation

nonisolated enum DeviceScan: Hashable {
  case barcode(String)
  case text(String)

  static func serialCandidates(in transcript: String) -> [String] {
    transcript.uppercased().split(separator: /\W+/).map(String.init).filter {
      ($0.count == 10 || $0.count == 12)
        && $0.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
    }
  }

  /// OCR can confuse these glyphs. This is an equivalence key, never a stored serial.
  static func serialKey(_ value: String) -> String {
    String(value.uppercased().map { character in
      switch character {
      case "O": "0"
      case "I", "L": "1"
      case "S": "5"
      case "Z": "2"
      case "B": "8"
      default: character
      }
    })
  }
}

struct DeviceScanLookup {
  private let barcodes: [String: [Device]]
  private let serials: [String: [Device]]

  init(devices: [Device]) {
    barcodes = Dictionary(grouping: devices, by: \.assetTag)
    serials = Dictionary(grouping: devices) { DeviceScan.serialKey($0.serial) }
  }

  func matches(_ scan: DeviceScan) -> [Device] {
    switch scan {
    case let .barcode(value): barcodes[value] ?? []
    case let .text(value): serials[DeviceScan.serialKey(value)] ?? []
    }
  }
}

nonisolated struct ScanFeedback: Equatable {
  let message: String
  var isSuccess = false
}

nonisolated struct DeviceScanSession: Equatable {
  private(set) var addedSerials: Set<String> = []
  private(set) var feedback: ScanFeedback?
  private var recentScans: [DeviceScan: ContinuousClock.Instant] = [:]
  private var feedbackUntil: ContinuousClock.Instant?

  mutating func accepts(_ scan: DeviceScan, now: ContinuousClock.Instant = .now) -> Bool {
    let key: DeviceScan = switch scan {
    case .barcode: scan
    case let .text(value): .text(DeviceScan.serialKey(value))
    }
    if let previous = recentScans[key], previous.duration(to: now) < .seconds(2) {
      return false
    }
    recentScans = recentScans.filter { $0.value.duration(to: now) < .seconds(2) }
    recentScans[key] = now
    return true
  }

  mutating func added(serial: String, label: String, now: ContinuousClock.Instant = .now) {
    guard addedSerials.insert(serial).inserted else { return }
    feedback = ScanFeedback(message: "Added \(label)", isSuccess: true)
    feedbackUntil = now.advanced(by: .seconds(2))
  }

  mutating func report(_ message: String, immediately: Bool = false, now: ContinuousClock.Instant = .now) {
    guard immediately || feedbackUntil.map({ now >= $0 }) ?? true else { return }
    feedback = ScanFeedback(message: message)
    feedbackUntil = now.advanced(by: .seconds(1))
  }
}
