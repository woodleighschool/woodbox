import SwiftUI

enum DeviceCondition: String, Codable, CaseIterable {
  case a = "A"
  case b = "B"
  case c = "C"
  case d = "D"

  var color: Color {
    switch self {
    case .a: .green
    case .b: .blue
    case .c: .orange
    case .d: .red
    }
  }

  var detail: String {
    switch self {
    case .a: "Like new, no visible wear, fully functional"
    case .b: "Minor cosmetic marks, fully functional"
    case .c: "Noticeable wear or scratches, fully functional"
    case .d: "Significant damage or defects, may have issues"
    }
  }
}
