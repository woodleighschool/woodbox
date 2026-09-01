import Foundation

@MainActor
protocol RepairServicing {
  func createCompnowTicket(for input: RepairSubmissionInput) async throws -> String
  func createFreshserviceTicket(
    for input: RepairSubmissionInput,
    compnowTicketId: String?
  ) async throws -> String
  func checkInSpare(_ spare: RepairSpareSnapshot) async throws
  func checkoutSpare(_ spare: RepairSpareSnapshot, to userId: Int) async throws
}

@MainActor
struct LiveRepairService: RepairServicing {
  let settings: AppSettings

  func createCompnowTicket(for input: RepairSubmissionInput) async throws -> String {
    guard let client = settings.compnowClient else {
      throw IntegrationError(
        action: "create repair ticket",
        integration: "Compnow",
        message: "The integration is not enabled or configured"
      )
    }

    return try await client.createCompnowTicket(
      CompnowTicketCreateRequest(
        product: input.device.model,
        serial: input.device.serial,
        firstName: input.endUserName,
        lastName: "",
        address1: settings.compnowAddress,
        suburb: settings.compnowSuburb,
        state: settings.compnowState,
        postcode: settings.compnowPostcode,
        email: settings.compnowEmail,
        phone: settings.compnowPhone,
        stockCode: nil,
        extras: nil,
        fault: input.problem,
        condition: nil,
        reference: nil
      )
    )
  }

  func createFreshserviceTicket(
    for input: RepairSubmissionInput,
    compnowTicketId: String?
  ) async throws -> String {
    guard let client = settings.freshserviceClient else {
      throw IntegrationError(
        action: "create repair ticket",
        integration: "Freshservice",
        message: "The integration is not enabled or configured"
      )
    }

    var customFields: [String: String] = [:]
    if let spareName = input.spare?.name.nilIfEmpty,
       let field = settings.freshserviceSpareField.nilIfEmpty
    {
      customFields[field] = spareName
    }
    if let compnowTicketId,
       let field = settings.freshserviceCompnowField.nilIfEmpty
    {
      customFields[field] = compnowTicketId
    }

    return try await client.createFreshserviceTicket(
      FreshserviceTicketRequest(
        email: input.endUserEmail,
        subject: "REPAIR - \(input.problem)",
        description: input.notes,
        status: .open,
        priority: .low,
        tags: ["repair"],
        customFields: customFields.isEmpty ? nil : customFields,
        workspaceId: settings.freshserviceWorkspaceId
      )
    )
  }

  func checkInSpare(_ spare: RepairSpareSnapshot) async throws {
    guard let client = settings.snipeItClient else {
      throw IntegrationError(
        action: "check in spare",
        integration: "Snipe-IT",
        message: "The integration is not enabled or configured"
      )
    }

    try await client.checkinSnipeItAsset(
      assetId: spare.assetId,
      request: SnipeItCheckinRequest(
        statusId: spare.statusId,
        name: nil,
        note: nil,
        locationId: nil
      )
    )
  }

  func checkoutSpare(_ spare: RepairSpareSnapshot, to userId: Int) async throws {
    guard let client = settings.snipeItClient else {
      throw IntegrationError(
        action: "check out spare",
        integration: "Snipe-IT",
        message: "The integration is not enabled or configured"
      )
    }

    try await client.checkoutSnipeItAsset(
      assetId: spare.assetId,
      request: SnipeItCheckoutRequest(
        assignedUser: userId,
        statusId: spare.statusId,
        note: nil
      )
    )
  }
}

@MainActor
struct RepairCoordinator {
  let service: any RepairServicing

  func submit(_ input: RepairSubmissionInput, state: RepairSubmissionState) async {
    guard !state.isRunning, !state.isComplete else { return }

    do {
      try validate(input)

      if input.createCompnowTicket, state.compnowTicketId == nil {
        state.begin("Creating Compnow ticket")
        state.compnowTicketId = try await service.createCompnowTicket(for: input)
      }

      if input.createFreshserviceTicket, state.freshserviceTicketId == nil {
        try Task.checkCancellation()
        state.begin("Creating Freshservice ticket")
        state.freshserviceTicketId = try await service.createFreshserviceTicket(
          for: input,
          compnowTicketId: state.compnowTicketId
        )
      }

      if let spare = input.spare, !state.spareCheckedOut {
        let userId = try requireSnipeItUserId(input.snipeItUserId)

        if spare.isAssigned, !state.spareCheckedIn {
          try Task.checkCancellation()
          state.begin("Checking in spare")
          try await service.checkInSpare(spare)
          state.spareCheckedIn = true
        }

        try Task.checkCancellation()
        state.begin("Checking out spare")
        try await service.checkoutSpare(spare, to: userId)
        state.spareCheckedOut = true
      }

      state.complete()
    } catch {
      state.fail(error)
    }
  }

  private func validate(_ input: RepairSubmissionInput) throws {
    guard input.problem.nilIfEmpty != nil else {
      throw RepairSubmissionError.missingProblem
    }
    guard input.hasWork else {
      throw RepairSubmissionError.noActions
    }
    if input.createFreshserviceTicket, input.endUserEmail.nilIfEmpty == nil {
      throw RepairSubmissionError.missingEmail
    }
    if input.spare != nil {
      _ = try requireSnipeItUserId(input.snipeItUserId)
    }
  }

  private func requireSnipeItUserId(_ userId: Int?) throws -> Int {
    guard let userId else { throw RepairSubmissionError.missingSnipeItUser }
    return userId
  }
}

private enum RepairSubmissionError: LocalizedError {
  case missingProblem
  case missingEmail
  case missingSnipeItUser
  case noActions

  var errorDescription: String? {
    switch self {
    case .missingProblem:
      "Describe the problem before submitting the repair."
    case .missingEmail:
      "An end-user email is required for the Freshservice ticket."
    case .missingSnipeItUser:
      "No Snipe-IT user matches the end-user email."
    case .noActions:
      "Select at least one repair outcome before submitting."
    }
  }
}
