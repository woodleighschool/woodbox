import Foundation

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

/// The steps already completed for one repair, so submitting again never repeats them.
@MainActor
final class RepairProgress {
  var compnowTicketId: String?
  var freshserviceTicketId: String?
  var spareCheckedIn = false
  var spareCheckedOut = false
}
