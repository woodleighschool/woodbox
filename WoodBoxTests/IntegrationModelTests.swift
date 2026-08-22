import Foundation
import Testing
@testable import WoodBox

@Suite("Integration wire models")
struct IntegrationModelTests {
  @Test("Snipe-IT updates flatten custom fields into the request")
  func encodesSnipeItUpdate() throws {
    let request = SnipeItUpdateRequest(
      statusId: 7,
      notes: nil,
      customFields: ["_snipeit_ram_4": "16 GB"]
    )

    let payload = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )

    #expect(payload["status_id"] as? Int == 7)
    #expect(payload["_snipeit_ram_4"] as? String == "16 GB")
    #expect(payload["notes"] == nil)
    #expect(payload["custom_fields"] == nil)
  }

  @Test("Freshservice requests use the API's snake-case keys")
  func encodesFreshserviceRequest() throws {
    let request = FreshserviceServiceRequestCreateRequest(
      email: "person@example.invalid",
      customFields: ["device_serial": "SERIAL-001"],
      workspaceId: 42
    )

    let payload = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    let customFields = try #require(payload["custom_fields"] as? [String: String])

    #expect(payload["email"] as? String == "person@example.invalid")
    #expect(payload["quantity"] as? Int == 1)
    #expect(payload["workspace_id"] as? Int == 42)
    #expect(customFields == ["device_serial": "SERIAL-001"])
  }
}
