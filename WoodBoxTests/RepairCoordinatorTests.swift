import Testing
@testable import WoodBox

@Suite("Repair coordinator")
@MainActor
struct RepairCoordinatorTests {
  @Test("repair creates both tickets then assigns the spare")
  func submitsRepairInOrder() async throws {
    let service = TestRepairService()
    let progress = RepairProgress()
    let coordinator = RepairCoordinator(service: service)

    try await coordinator.submit(makeInput(), progress: progress)

    #expect(service.events == [
      .compnow,
      .freshservice(compnowTicketId: "CN-42"),
      .checkIn(assetId: 7),
      .checkout(assetId: 7, userId: 19),
    ])
    #expect(progress.compnowTicketId == "CN-42")
    #expect(progress.freshserviceTicketId == "FS-84")
    #expect(progress.spareCheckedIn)
    #expect(progress.spareCheckedOut)
  }

  @Test("submitting again resumes after the last completed step")
  func retrySkipsCompletedWork() async throws {
    let service = TestRepairService()
    service.failFreshservice = true
    let progress = RepairProgress()
    let coordinator = RepairCoordinator(service: service)

    await #expect(throws: TestRepairError.self) {
      try await coordinator.submit(makeInput(), progress: progress)
    }

    #expect(service.events == [.compnow, .freshservice(compnowTicketId: "CN-42")])
    #expect(progress.compnowTicketId == "CN-42")
    #expect(progress.freshserviceTicketId == nil)
    #expect(!progress.spareCheckedOut)

    service.failFreshservice = false
    service.events.removeAll()
    try await coordinator.submit(makeInput(), progress: progress)

    #expect(service.events == [
      .freshservice(compnowTicketId: "CN-42"),
      .checkIn(assetId: 7),
      .checkout(assetId: 7, userId: 19),
    ])
    #expect(progress.spareCheckedOut)
  }

  @Test("missing spare user fails before tickets are created")
  func validatesBeforeExternalWork() async {
    let service = TestRepairService()
    let progress = RepairProgress()
    let coordinator = RepairCoordinator(service: service)

    do {
      try await coordinator.submit(makeInput(snipeItUserId: nil), progress: progress)
      Issue.record("A spare cannot be checked out without a Snipe-IT user")
    } catch {
      #expect(error.localizedDescription == "No Snipe-IT user matches the end-user email.")
    }

    #expect(service.events.isEmpty)
    #expect(progress.compnowTicketId == nil)
  }

  @Test("repair performs only the selected outcomes")
  func performsOnlySelectedOutcomes() async throws {
    let service = TestRepairService()
    let coordinator = RepairCoordinator(service: service)

    try await coordinator.submit(
      makeInput(createFreshserviceTicket: false, includesSpare: false),
      progress: RepairProgress()
    )

    #expect(service.events == [.compnow])
  }

  private func makeInput(
    createFreshserviceTicket: Bool = true,
    includesSpare: Bool = true,
    snipeItUserId: Int? = 19
  ) -> RepairSubmissionInput {
    RepairSubmissionInput(
      device: RepairDeviceSnapshot(serial: "SERIAL-001", model: "MacBook Air"),
      endUserName: "Test User",
      endUserEmail: "person@example.invalid",
      problem: "Broken display",
      notes: "No external damage",
      createCompnowTicket: true,
      createFreshserviceTicket: createFreshserviceTicket,
      spare: includesSpare
        ? RepairSpareSnapshot(
          assetId: 7,
          name: "Spare 7",
          statusId: 3,
          isAssigned: true
        )
        : nil,
      snipeItUserId: snipeItUserId
    )
  }
}

@MainActor
private final class TestRepairService: RepairServicing {
  enum Event: Equatable {
    case compnow
    case freshservice(compnowTicketId: String?)
    case checkIn(assetId: Int)
    case checkout(assetId: Int, userId: Int)
  }

  var events: [Event] = []
  var failFreshservice = false

  func createCompnowTicket(for _: RepairSubmissionInput) async throws -> String {
    events.append(.compnow)
    return "CN-42"
  }

  func createFreshserviceTicket(
    for _: RepairSubmissionInput,
    compnowTicketId: String?
  ) async throws -> String {
    events.append(.freshservice(compnowTicketId: compnowTicketId))
    if failFreshservice {
      throw TestRepairError.failed
    }
    return "FS-84"
  }

  func checkInSpare(_ spare: RepairSpareSnapshot) async throws {
    events.append(.checkIn(assetId: spare.assetId))
  }

  func checkoutSpare(_ spare: RepairSpareSnapshot, to userId: Int) async throws {
    events.append(.checkout(assetId: spare.assetId, userId: userId))
  }
}

private enum TestRepairError: Error {
  case failed
}
