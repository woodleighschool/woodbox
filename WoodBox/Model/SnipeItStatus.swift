import Foundation
import SwiftData

@Model
final class SnipeItStatus {
  @Attribute(.unique) var snipeItId: Int
  var name: String

  init(snipeItId: Int, name: String) {
    self.snipeItId = snipeItId
    self.name = name
  }
}
