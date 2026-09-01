import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct SaleCSV: Transferable {
  struct Row: Sendable {
    let serial: String
    let assetTag: String
    let model: String
    let status: String
    let grade: String
    let conditionNotes: String
    let result: String
  }

  let rows: [Row]

  var contents: String {
    var lines = ["Serial,Asset Tag,Model,Status,Grade,Condition Notes,Result"]
    lines += rows.map { row in
      [
        row.serial,
        row.assetTag,
        row.model,
        row.status,
        row.grade,
        row.conditionNotes,
        row.result,
      ]
      .map(Self.escape)
      .joined(separator: ",")
    }
    return lines.joined(separator: "\n")
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
      let url = FileManager.default.temporaryDirectory.appending(path: "sale-devices.csv")
      try csv.contents.write(to: url, atomically: true, encoding: .utf8)
      return SentTransferredFile(url)
    }
  }

  private static func escape(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}

extension SaleCSV {
  @MainActor
  init(items: [DeviceProcessingItem], fallbackStatusName: String?) {
    rows = items.map { item in
      Row(
        serial: item.serial,
        assetTag: item.assetTag,
        model: item.deviceModel,
        status: item.targetStatusName ?? fallbackStatusName ?? "",
        grade: item.grade?.rawValue ?? "",
        conditionNotes: item.conditionNotes,
        result: item.state.rawValue
      )
    }
  }
}
