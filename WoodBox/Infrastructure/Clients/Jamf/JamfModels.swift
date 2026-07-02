//
//  JamfModels.swift
//  WoodBox
//
//  Created by Alexander Hyde on 8/2/2026.
//

import Foundation

// MARK: Computers

/// Response
struct JamfComputersResponse: Decodable {
  let results: [JamfComputer]
}

struct JamfComputer: Decodable {
  let id: String
  let general: JamfComputerGeneral
  let hardware: JamfComputerHardware
}

struct JamfComputerGeneral: Decodable {
  let lastContactTime: String?
  let name: String?
}

struct JamfComputerHardware: Decodable {
  let serialNumber: String
}

// MARK: Mobile Devices

/// Response
struct JamfMobileDevicesResponse: Decodable {
  let results: [JamfMobileDevice]
}

struct JamfMobileDevice: Decodable {
  let mobileDeviceId: String
  let displayName: String?
  let general: JamfMobileDeviceGeneral
  let hardware: JamfMobileDeviceHardware

  var name: String? {
    general.displayName ?? displayName
  }
}

struct JamfMobileDeviceGeneral: Decodable {
  let displayName: String?
  let lastInventoryUpdateDate: String?
}

struct JamfMobileDeviceHardware: Decodable {
  let serialNumber: String
}
