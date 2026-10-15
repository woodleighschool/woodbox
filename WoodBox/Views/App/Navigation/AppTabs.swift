import SwiftUI

enum AppTab: Hashable, Identifiable {
  case repairIntake
  case restock
  case sale
  case deviceDeduplication
  case enrollment

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .repairIntake: "Repair"
    case .restock: "Restock"
    case .sale: "Sale"
    case .deviceDeduplication: "Dedupe"
    case .enrollment: "Enrollment"
    }
  }

  var symbol: String {
    switch self {
    case .repairIntake: "wrench.and.screwdriver"
    case .restock: DeviceProcessingProfile.restock.symbol
    case .sale: DeviceProcessingProfile.sale.symbol
    case .deviceDeduplication: "rectangle.on.rectangle.slash"
    case .enrollment: "laptopcomputer.and.arrow.down"
    }
  }
}
