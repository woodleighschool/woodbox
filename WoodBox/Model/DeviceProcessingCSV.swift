import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct DeviceProcessingCSV: Transferable {
  struct Row: Sendable {
    let serial: String
    let assetTag: String
    let model: String
    let status: String
    let grade: String
    let conditionNotes: String
  }

  let rows: [Row]

  var contents: String {
    var lines = ["Serial,Asset Tag,Model,Status,Grade,Condition Notes"]
    lines += rows.map { row in
      [
        row.serial,
        row.assetTag,
        row.model,
        row.status,
        row.grade,
        row.conditionNotes,
      ]
      .map(Self.escape)
      .joined(separator: ",")
    }
    return lines.joined(separator: "\n")
  }

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
      Data(csv.contents.utf8)
    }
    .suggestedFileName("devices.csv")
  }

  private static func escape(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}

extension DeviceProcessingCSV {
  @MainActor
  init(items: [DeviceProcessingItem], statusName: String?) {
    rows = items.map { item in
      Row(
        serial: item.serial,
        assetTag: item.assetTag,
        model: item.deviceModel,
        status: statusName ?? "",
        grade: item.grade?.rawValue ?? "",
        conditionNotes: item.conditionNotes
      )
    }
  }
}
