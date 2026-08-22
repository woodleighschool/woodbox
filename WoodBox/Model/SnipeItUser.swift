import Foundation
import SwiftData

@Model
final class SnipeItUser {
  // MARK: - Properties

  @Attribute(.unique) var snipeItId: Int
  var name: String?
  var email: String?

  // MARK: - Init

  init(snipeItId: Int, name: String?, email: String?) {
    self.snipeItId = snipeItId
    self.name = name
    self.email = email
  }
}
