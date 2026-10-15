import Foundation
import Testing
@testable import WoodBox

@Suite("Inventory requests")
@MainActor
struct InventoryClientTests {
  @Test("serial lookup rejects blank identifiers before reading provider configuration", arguments: ["", " ", "\n\t"])
  func rejectsBlankSerial(serial: String) async throws {
    let settings = try AppSettings(defaults: #require(UserDefaults(suiteName: UUID().uuidString)), usesKeychain: false)
    do {
      _ = try await MDMInventoryService(settings: settings).fetch(serial: serial)
      Issue.record("Expected a blank serial to fail")
    } catch {
      #expect(error.localizedDescription.contains("serial number is required"))
    }
  }

  @Test("Intune requests list fields and follows every page")
  func intuneProjectionAndPaging() async throws {
    let server = InventoryStub()
    let client = IntuneClient(
      tenantId: "test",
      clientId: "test",
      clientSecret: "test",
      http: HTTPClient { try await server.respond($0) }
    )
    let records = try await client.fetchIntuneDevices(serial: "SERIAL-1")
    #expect(records.map(\.id) == ["first", "second"])
    let requests = await server.requests
    #expect(requests.count == 2)
    let items = URLComponents(url: requests[0], resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.first { $0.name == "$select" }?.value == "id,deviceName,serialNumber,lastSyncDateTime,model")
    #expect(items.first { $0.name == "$filter" }?.value == "serialNumber eq 'SERIAL-1'")
    #expect(requests[1].absoluteString == "https://graph.microsoft.com/v1.0/next")
  }
}

private actor InventoryStub {
  var requests: [URL] = []

  func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
    let url = request.url!
    let body: String
    if url.host == "login.microsoftonline.com" {
      body = #"{"access_token":"test-token","expires_in":3600}"#
    } else {
      requests.append(url)
      body = requests.count == 1
        ? #"{"value":[{"id":"first","serialNumber":"SERIAL-1"}],"@odata.nextLink":"https://graph.microsoft.com/v1.0/next"}"#
        : #"{"value":[{"id":"second","serialNumber":"SERIAL-1"}]}"#
    }
    return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
  }
}
