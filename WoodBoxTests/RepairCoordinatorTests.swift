import Testing
@testable import WoodBox

@Suite("Repair coordinator")
@MainActor
struct RepairCoordinatorTests {
  @Test("repair creates both tickets then assigns the spare")
  func submitsRepairInOrder() async {
    let service = TestRepairService()
    let state = RepairSubmissionState()
    let coordinator = RepairCoordinator(service: service)

    await coordinator.submit(makeInput(), state: state)

    #expect(service.events == [
      .compnow,
      .freshservice(compnowTicketId: "CN-42"),
      .checkIn(assetId: 7),
      .checkout(assetId: 7, userId: 19),
    ])
    #expect(state.compnowTicketId == "CN-42")
    #expect(state.freshserviceTicketId == "FS-84")
    #expect(state.spareCheckedIn)
    #expect(state.spareCheckedOut)
    #expect(state.isComplete)
  }

  @Test("retry resumes after the last confirmed step")
  func retrySkipsCompletedWork() async {
    let service = TestRepairService()
    service.failFreshservice = true
    let state = RepairSubmissionState()
    let coordinator = RepairCoordinator(service: service)

    await coordinator.submit(makeInput(), state: state)

    #expect(service.events == [.compnow, .freshservice(compnowTicketId: "CN-42")])
    #expect(state.compnowTicketId == "CN-42")
    #expect(state.freshserviceTicketId == nil)
    #expect(!state.isComplete)

    service.failFreshservice = false
    service.events.removeAll()
    await coordinator.submit(makeInput(), state: state)

    #expect(service.events == [
      .freshservice(compnowTicketId: "CN-42"),
      .checkIn(assetId: 7),
      .checkout(assetId: 7, userId: 19),
    ])
    #expect(state.isComplete)
  }

  @Test("missing spare user fails before tickets are created")
  func validatesBeforeExternalWork() async {
    let service = TestRepairService()
    let state = RepairSubmissionState()
    let coordinator = RepairCoordinator(service: service)
    let input = makeInput(snipeItUserId: nil)

    await coordinator.submit(input, state: state)

    #expect(service.events.isEmpty)
    #expect(state.errorMessage == "No Snipe-IT user matches the end-user email.")
    #expect(!state.hasStarted)
  }

  @Test("repair performs only the selected outcomes")
  func performsOnlySelectedOutcomes() async {
    let service = TestRepairService()
    let state = RepairSubmissionState()
    let coordinator = RepairCoordinator(service: service)

    await coordinator.submit(
      makeInput(createFreshserviceTicket: false, includesSpare: false),
      state: state
    )

    #expect(service.events == [.compnow])
    #expect(state.isComplete)
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
