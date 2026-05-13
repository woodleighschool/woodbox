//
//  BulkScanHistoryItem.swift
//  WoodBox
//
//  Created by Alexander Hyde on 28/2/2026.
//

#if os(iOS)
  import Foundation
  import SwiftData

  @Model
  final class BulkScanHistoryItem {
    var scannedAt: Date
    @Relationship var device: Device

    init(device: Device, scannedAt: Date = .now) {
      self.device = device
      self.scannedAt = scannedAt
    }
  }
#endif
