import SwiftData
import Testing
@testable import WoodBox

@Suite("Device processing coordinator")
@MainActor
struct DeviceProcessingCoordinatorTests {
  @Test("Sale drafts persist their grade and optional notes")
  func saleDraftCarriesCondition() throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: false)
    let item = DeviceProcessingItem(
      .sale(device, grade: .c, conditionNotes: "  Light wear  ")
    )

    #expect(item.profile == .sale)
    #expect(item.grade == .c)
    #expect(item.conditionNotes == "Light wear")
  }

  @Test("an assigned Sale device is removed from MDM before check-in and condition update")
  func processesAssignedSaleDeviceInOrder() async throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: true)
    fixture.addMDMRecords(to: device)
    let item = fixture.makeItem(profile: .sale, device: device)
    item.grade = .b
    item.conditionNotes = "Light marks on lid"

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 7,
      targetStatusName: "Selected Status",
      conditionField: "grade_field",
      conditionNotesField: "notes_field"
    )

    #expect(fixture.service.events == [
      .delete(.jamf, "jamf-1"),
      .delete(.intune, "intune-1"),
      .checkIn(assetId: 42, statusId: 7),
      .update(
        assetId: 42,
        statusId: nil,
        fields: [
          "grade_field": "B",
          "notes_field": "Light marks on lid",
        ]
      ),
    ])
    #expect(device.mdmRecords.isEmpty)
    #expect(device.assignedUserName == nil)
    #expect(device.assignedUserEmail == nil)
    #expect(device.statusId == 7)
    #expect(device.status == "Selected Status")
    #expect(item.state == .completed)
  }

  @Test("an MDM failure keeps the record and prevents the Snipe-IT transition")
  func stopsAtMDMFailure() async throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: false)
    fixture.addMDMRecords(to: device, providers: [.jamf])
    let item = fixture.makeItem(profile: .restock, device: device)
    fixture.service.failingDeletionId = "jamf-1"

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 9,
      targetStatusName: "Any Status",
      conditionField: "",
      conditionNotesField: ""
    )

    #expect(fixture.service.events == [.delete(.jamf, "jamf-1")])
    #expect(device.mdmRecords.map(\.deviceId) == ["jamf-1"])
    #expect(device.statusId == nil)
    #expect(item.state == .failed)
    #expect(item.failureStage == .mdm)
  }

  @Test("an unassigned Restock device applies only the selected status")
  func updatesUnassignedRestockDevice() async throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: false)
    let item = fixture.makeItem(profile: .restock, device: device)

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 11,
      targetStatusName: "Open Semantics",
      conditionField: "grade_field",
      conditionNotesField: "notes_field"
    )

    #expect(fixture.service.events == [
      .update(assetId: 42, statusId: 11, fields: [:]),
    ])
    #expect(item.state == .completed)
  }

  @Test("missing Snipe-IT identity fails before destructive work")
  func validatesIdentityBeforeDeletingMDM() async throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: false, snipeItId: nil)
    fixture.addMDMRecords(to: device, providers: [.jamf])
    let item = fixture.makeItem(profile: .restock, device: device)

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 3,
      targetStatusName: "Selected Status",
      conditionField: "",
      conditionNotesField: ""
    )

    #expect(fixture.service.events.isEmpty)
    #expect(device.mdmRecords.count == 1)
    #expect(item.state == .failed)
    #expect(item.failureStage == .validation)
  }

  @Test("retry resumes after successful MDM deletion")
  func retriesOnlyRemainingWork() async throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: false)
    fixture.addMDMRecords(to: device, providers: [.intune])
    let item = fixture.makeItem(profile: .restock, device: device)
    fixture.service.failSnipeUpdate = true

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 4,
      targetStatusName: "Selected Status",
      conditionField: "",
      conditionNotesField: ""
    )

    #expect(item.failureStage == .snipeIt)
    #expect(device.mdmRecords.isEmpty)

    fixture.service.failSnipeUpdate = false
    fixture.service.events.removeAll()

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 4,
      targetStatusName: "Selected Status",
      conditionField: "",
      conditionNotesField: ""
    )

    #expect(fixture.service.events == [
      .update(assetId: 42, statusId: 4, fields: [:]),
    ])
    #expect(item.state == .completed)
  }

  @Test("retry does not check in an assigned device twice")
  func retrySkipsCompletedCheckIn() async throws {
    let fixture = try ProcessingFixture()
    let device = fixture.makeDevice(assigned: true)
    let item = fixture.makeItem(profile: .sale, device: device)
    item.grade = .a
    item.conditionNotes = "As new"
    fixture.service.failSnipeUpdate = true

    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 8,
      targetStatusName: "Selected Status",
      conditionField: "grade_field",
      conditionNotesField: "notes_field"
    )

    #expect(fixture.service.events == [
      .checkIn(assetId: 42, statusId: 8),
      .update(
        assetId: 42,
        statusId: nil,
        fields: ["grade_field": "A", "notes_field": "As new"]
      ),
    ])
    #expect(item.snipeItCheckedIn)
    #expect(device.assignedUserEmail == nil)

    fixture.service.failSnipeUpdate = false
    fixture.service.events.removeAll()
    await fixture.coordinator.process(
      item: item,
      device: device,
      targetStatusId: 12,
      targetStatusName: "Changed Status",
      conditionField: "grade_field",
      conditionNotesField: "notes_field"
    )

    #expect(fixture.service.events == [
      .update(
        assetId: 42,
        statusId: 12,
        fields: ["grade_field": "A", "notes_field": "As new"]
      ),
    ])
    #expect(device.statusId == 12)
    #expect(device.status == "Changed Status")
    #expect(item.state == .completed)
  }
}

@MainActor
private final class ProcessingFixture {
  let context: ModelContext
  let service = TestDeviceProcessingService()
  let coordinator: DeviceProcessingCoordinator

  init() throws {
    let schema = Schema([Device.self, MDMRecord.self, DeviceProcessingItem.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    context = ModelContext(container)
    coordinator = DeviceProcessingCoordinator(service: service, modelContext: context)
  }

  func makeDevice(assigned: Bool, snipeItId: Int? = 42) -> Device {
    let device = Device(serial: "SERIAL-001", assetTag: "ASSET-001", model: "MacBook Air")
    device.snipeItId = snipeItId
    if assigned {
      device.assignedUserName = "Test User"
      device.assignedUserEmail = "person@example.invalid"
    }
    context.insert(device)
    return device
  }

  func addMDMRecords(
    to device: Device,
    providers: [MDMProvider] = [.jamf, .intune]
  ) {
    device.mdmRecords = providers.map { provider in
      MDMRecord(
        provider: provider,
        deviceId: provider == .jamf ? "jamf-1" : "intune-1",
        deviceName: "test-device",
        lastCheckIn: nil,
        jamfDeviceType: provider == .jamf ? .computer : nil,
        device: device
      )
    }
  }

  func makeItem(profile: DeviceProcessingProfile, device: Device) -> DeviceProcessingItem {
    let draft: DeviceProcessingDraft = switch profile {
    case .restock:
      .restock(device)
    case .sale:
      .sale(device, grade: .b, conditionNotes: "")
    }
    let item = DeviceProcessingItem(draft)
    context.insert(item)
    return item
  }
}

@MainActor
private final class TestDeviceProcessingService: DeviceProcessingServicing {
  enum Event: Equatable {
    case delete(MDMProvider, String)
    case checkIn(assetId: Int, statusId: Int)
    case update(assetId: Int, statusId: Int?, fields: [String: String])
  }

  var events: [Event] = []
  var failingDeletionId: String?
  var failSnipeUpdate = false

  func deleteMDMRecord(_ request: MDMDeletionService.Request) async throws {
    events.append(.delete(request.provider, request.deviceId))
    if request.deviceId == failingDeletionId {
      throw TestProcessingError.failed
    }
  }

  func checkInSnipeItAsset(assetId: Int, statusId: Int) async throws {
    events.append(.checkIn(assetId: assetId, statusId: statusId))
  }

  func updateSnipeItAsset(
    assetId: Int,
    statusId: Int?,
    customFields: [String: String]?
  ) async throws {
    events.append(.update(assetId: assetId, statusId: statusId, fields: customFields ?? [:]))
    if failSnipeUpdate {
      throw TestProcessingError.failed
    }
  }
}

private enum TestProcessingError: Error {
  case failed
}
