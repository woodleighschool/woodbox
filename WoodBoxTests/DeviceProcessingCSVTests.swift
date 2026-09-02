import CoreTransferable
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import WoodBox

@Suite("Device processing CSV")
struct DeviceProcessingCSVTests {
  @Test("exports every field and escapes CSV content")
  func exportsRows() {
    let csv = DeviceProcessingCSV(
      rows: [
        DeviceProcessingCSV.Row(
          serial: "SERIAL-001",
          assetTag: "ASSET-001",
          model: "MacBook Air, 13-inch",
          status: "Ready for Sale",
          grade: "B",
          conditionNotes: "Marks on lid; called \"well used\""
        ),
      ]
    )

    #expect(
      csv.contents == #"""
      Serial,Asset Tag,Model,Status,Grade,Condition Notes
      "SERIAL-001","ASSET-001","MacBook Air, 13-inch","Ready for Sale","B","Marks on lid; called ""well used"""
      """#
    )
  }

  @MainActor
  @Test("Restock exports the queued snapshots without a selected status")
  func exportsRestockItems() {
    let device = Device(serial: "SERIAL-001", assetTag: "ASSET-001", model: "MacBook Air")
    let item = DeviceProcessingItem(.restock(device))
    device.assetTag = "CHANGED-ASSET"
    device.model = "Changed model"

    let csv = DeviceProcessingCSV(items: [item], statusName: nil)

    #expect(
      csv.contents == #"""
      Serial,Asset Tag,Model,Status,Grade,Condition Notes
      "SERIAL-001","ASSET-001","MacBook Air","","",""
      """#
    )
  }

  @MainActor
  @Test("Sale exports the selected status and captured condition")
  func exportsSaleItems() {
    let device = Device(serial: "SERIAL-002", assetTag: "ASSET-002", model: "MacBook Pro")
    let item = DeviceProcessingItem(.sale(device, grade: .b, conditionNotes: "Light marks on lid"))
    let csv = DeviceProcessingCSV(items: [item], statusName: "Ready for Sale")

    #expect(
      csv.contents == #"""
      Serial,Asset Tag,Model,Status,Grade,Condition Notes
      "SERIAL-002","ASSET-002","MacBook Pro","Ready for Sale","B","Light marks on lid"
      """#
    )
  }

  @Test("sharing supplies a named UTF-8 CSV file")
  func sharesCSVFile() async throws {
    let csv = DeviceProcessingCSV(rows: [
      DeviceProcessingCSV.Row(
        serial: "SERIAL-003",
        assetTag: "ASSET-003",
        model: "MacBook Air",
        status: "",
        grade: "C",
        conditionNotes: "Écran marqué\nDent on lid"
      ),
    ])
    let provider = NSItemProvider()
    provider.register(csv)

    let data: Data = try await withCheckedThrowingContinuation { continuation in
      _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.commaSeparatedText.identifier) { url, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        do {
          let url = try #require(url)
          try continuation.resume(returning: Data(contentsOf: url))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }

    #expect(provider.suggestedName == "devices.csv")
    #expect(String(decoding: data, as: UTF8.self) == csv.contents)
  }
}
