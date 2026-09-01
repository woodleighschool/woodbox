import Testing
@testable import WoodBox

@Suite("Sale CSV")
struct SaleCSVTests {
  @Test("exports every field and escapes CSV content")
  func exportsRows() {
    let csv = SaleCSV(
      rows: [
        SaleCSV.Row(
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
}
