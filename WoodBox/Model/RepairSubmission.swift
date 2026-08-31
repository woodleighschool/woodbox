import Foundation
import Observation

struct RepairDeviceSnapshot: Equatable {
  let serial: String
  let model: String
}

struct RepairSpareSnapshot: Equatable {
  let assetId: Int
  let name: String?
  let statusId: Int
  let isAssigned: Bool
}

struct RepairSubmissionInput: Equatable {
  let device: RepairDeviceSnapshot
  let endUserName: String
  let endUserEmail: String
  let problem: String
  let notes: String
  let createCompnowTicket: Bool
  let createFreshserviceTicket: Bool
  let spare: RepairSpareSnapshot?
  let snipeItUserId: Int?

  var hasWork: Bool {
    createCompnowTicket || createFreshserviceTicket || spare != nil
  }
}

@MainActor
@Observable
final class RepairSubmissionState {
  var compnowTicketId: String?
  var freshserviceTicketId: String?
  var spareCheckedIn = false
  var spareCheckedOut = false
  var isRunning = false
  var isComplete = false
  var hasAttempted = false
  var operationMessage: String?
  var errorMessage: String?

  var hasStarted: Bool {
    hasAttempted
      || compnowTicketId != nil
      || freshserviceTicketId != nil
      || spareCheckedIn
      || spareCheckedOut
      || isRunning
      || isComplete
  }

  func begin(_ message: String) {
    hasAttempted = true
    isRunning = true
    operationMessage = message
    errorMessage = nil
  }

  func fail(_ error: Error) {
    isRunning = false
    operationMessage = nil
    errorMessage = error.localizedDescription
  }

  func complete() {
    isRunning = false
    isComplete = true
    operationMessage = nil
    errorMessage = nil
  }

  func reset() {
    compnowTicketId = nil
    freshserviceTicketId = nil
    spareCheckedIn = false
    spareCheckedOut = false
    isRunning = false
    isComplete = false
    hasAttempted = false
    operationMessage = nil
    errorMessage = nil
  }
}
