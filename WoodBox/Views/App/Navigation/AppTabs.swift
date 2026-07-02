//
//  AppTabs.swift
//  WoodBox
//
//  Created by Alexander Hyde on 21/2/2026.
//

import SwiftUI

enum AppTab: Hashable, Identifiable {
  case repairIntake
  case returnCheckIn
  case salePreparation
  case deviceDeduplication
  #if os(iOS)
    case bulkScanner
  #endif

  var id: Self {
    self
  }

  var title: String {
    #if os(iOS)
      switch self {
      case .repairIntake: return "Repair"
      case .returnCheckIn: return "Return"
      case .salePreparation: return "Sale"
      case .deviceDeduplication: return "Dedupe"
      case .bulkScanner: return "Bulk Scanner"
      }
    #else
      switch self {
      case .repairIntake: return "Repair Intake"
      case .returnCheckIn: return "Return Check-In"
      case .salePreparation: return "Sale Preparation"
      case .deviceDeduplication: return "Device Deduplication"
      }
    #endif
  }

  var symbol: String {
    switch self {
    case .repairIntake: "wrench.and.screwdriver"
    case .returnCheckIn: "arrow.uturn.left.circle"
    case .salePreparation: "tag"
    case .deviceDeduplication: "rectangle.on.rectangle.slash"
    #if os(iOS)
      case .bulkScanner: "camera.viewfinder"
    #endif
    }
  }
}
