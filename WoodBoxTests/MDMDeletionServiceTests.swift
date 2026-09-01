import SwiftData
import Testing
@testable import WoodBox

@Suite("MDM deletion")
@MainActor
struct MDMDeletionServiceTests {
  @Test("a remote request can be preserved before removing the local record")
  func preservesRequestBeforeLocalRemoval() throws {
    let schema = Schema([Device.self, MDMRecord.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    let device = Device(serial: "SERIAL-001", assetTag: "ASSET-001", model: "MacBook Air")
    let jamfRecord = MDMRecord(
      provider: .jamf,
      deviceId: "101",
      deviceName: "macbook-001",
      lastCheckIn: nil,
      jamfDeviceType: .computer,
      device: device
    )
    let intuneRecord = MDMRecord(
      provider: .intune,
      deviceId: "202",
      deviceName: "macbook-001",
      lastCheckIn: nil,
      jamfDeviceType: nil,
      device: device
    )
    device.mdmRecords = [jamfRecord, intuneRecord]
    context.insert(device)
    try context.save()

    let request = MDMDeletionService.Request(record: jamfRecord)
    let localRecord = MDMDeletionService.LocalRecord(record: jamfRecord)
    try MDMDeletionService.removeLocally(
      jamfRecord,
      from: device,
      modelContext: context
    )

    #expect(request.provider == .jamf)
    #expect(request.deviceId == "101")
    #expect(request.jamfDeviceType == .computer)
    #expect(device.mdmRecords.map(\.id) == [intuneRecord.id])

    let persistedRecords = try context.fetch(FetchDescriptor<MDMRecord>())
    #expect(persistedRecords.map(\.id) == [intuneRecord.id])

    let restored = try MDMDeletionService.restoreLocally(
      localRecord,
      to: device,
      modelContext: context
    )
    #expect(restored.provider == .jamf)
    #expect(restored.deviceId == "101")
    #expect(Set(device.mdmRecords.map(\.id)) == Set([intuneRecord.id, restored.id]))
  }
}
