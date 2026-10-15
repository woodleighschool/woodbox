import Foundation
import Testing
@testable import WoodBox

@Suite("Snipe-IT mutation responses")
@MainActor
struct SnipeITClientTests {
  @Test("HTTP success with a transaction error is not a completed mutation")
  func rejectsTransactionFailure() async throws {
    let client = try SnipeITClient(
      baseURL: #require(URL(string: "https://snipe.example.invalid")),
      apiToken: "test",
      http: HTTPClient { request in
        (
          Data(#"{"status":"error","messages":{"status_id":["The selected status is invalid."]}}"#.utf8),
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
      }
    )
    do {
      try await client.updateSnipeItAsset(assetId: 7, request: SnipeItUpdateRequest(statusId: 3, notes: nil, customFields: nil))
      Issue.record("A rejected status must not be reported as applied")
    } catch {
      #expect((error as? IntegrationError)?.message == "The selected status is invalid.")
    }
  }

  @Test("a confirmed transaction completes")
  func acceptsTransactionSuccess() async throws {
    let client = try SnipeITClient(
      baseURL: #require(URL(string: "https://snipe.example.invalid")),
      apiToken: "test",
      http: HTTPClient { request in
        (
          Data(#"{"status":"success","messages":"Saved"}"#.utf8),
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
      }
    )
    try await client.updateSnipeItAsset(assetId: 7, request: SnipeItUpdateRequest(statusId: 3, notes: nil, customFields: nil))
  }
}
