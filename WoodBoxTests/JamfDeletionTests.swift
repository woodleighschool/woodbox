import Foundation
import Testing
@testable import WoodBox

@Suite("Jamf deletion responses")
@MainActor
struct JamfDeletionTests {
  @Test("successful and already absent records require no second request", arguments: [200, 204, 404])
  func completed(status: Int) async throws {
    let server = JamfStub(replies: [.status(status)])
    try await delete(.computer, server: server)
    #expect(await server.methods == ["DELETE"])
  }

  @Test("a timeout with confirmed absence is successful", arguments: [JamfDeviceType.computer, .mobile])
  func lostResponse(type: JamfDeviceType) async throws {
    let server = JamfStub(replies: [.failure(.timedOut), .status(404)])
    try await delete(type, server: server)
    #expect(await server.methods == ["DELETE", "GET"])
    #expect(await server.paths.allSatisfy { $0 == path(for: type) })
  }

  @Test("a server error is reconciled through delayed deletion", arguments: [JamfDeviceType.computer, .mobile])
  func delayedDeletion(type: JamfDeviceType) async throws {
    let server = JamfStub(replies: [.status(500), .status(200), .status(404)])
    try await delete(type, server: server)
    #expect(await server.methods == ["DELETE", "GET", "GET"])
  }

  @Test("a record that still exists preserves the original failure")
  func stillPresent() async {
    let server = JamfStub(replies: [.status(500), .status(200), .status(200), .status(200)])
    do {
      try await delete(.computer, server: server)
      Issue.record("An existing record must not be reported as deleted")
    } catch {
      #expect((error as? IntegrationError)?.statusCode == 500)
    }
    #expect(await server.methods == ["DELETE", "GET", "GET", "GET"])
  }

  @Test("an unreadable verification preserves the delete failure")
  func cannotVerify() async {
    let server = JamfStub(replies: [.failure(.networkConnectionLost), .status(403)])
    do {
      try await delete(.mobile, server: server)
      Issue.record("Unable to verify deletion")
    } catch {
      #expect((error as? URLError)?.code == .networkConnectionLost)
    }
    #expect(await server.methods == ["DELETE", "GET"])
  }

  @Test("permission failures are not retried or treated as absence")
  func forbidden() async {
    let server = JamfStub(replies: [.status(403)])
    do {
      try await delete(.mobile, server: server)
      Issue.record("A permission failure must be reported")
    } catch {
      #expect((error as? IntegrationError)?.statusCode == 403)
    }
    #expect(await server.methods == ["DELETE"])
  }

  @Test("cancelled requests do not start verification")
  func cancellation() async {
    let server = JamfStub(replies: [.failure(.cancelled)])
    do {
      try await delete(.computer, server: server)
      Issue.record("Cancellation must be propagated")
    } catch {
      #expect((error as? URLError)?.code == .cancelled)
    }
    #expect(await server.methods == ["DELETE"])
  }

  @Test("an unavailable token endpoint is not mistaken for a deleted device")
  func tokenEndpointNotFound() async throws {
    let client = try JamfClient(
      baseURL: #require(URL(string: "https://jamf.example.invalid")), clientId: "test", clientSecret: "test",
      http: HTTPClient { request in
        #expect(request.httpMethod == "POST")
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
      }
    )
    do {
      try await client.deleteJamfComputer(id: "123")
      Issue.record("A token failure must not count as a deletion")
    } catch {
      #expect((error as? IntegrationError)?.integration == "OAuth")
      #expect((error as? IntegrationError)?.statusCode == 404)
    }
  }

  private func delete(_ type: JamfDeviceType, server: JamfStub) async throws {
    let client = JamfClient(
      baseURL: URL(string: "https://jamf.example.invalid")!,
      clientId: "test-client", clientSecret: "test-secret",
      http: HTTPClient { try await server.respond($0) }
    )
    switch type {
    case .computer: try await client.deleteJamfComputer(id: "123")
    case .mobile: try await client.deleteJamfMobileDevice(id: "123")
    }
  }

  private func path(for type: JamfDeviceType) -> String {
    type == .mobile ? "/JSSResource/mobiledevices/id/123" : "/api/v3/computers-inventory/123"
  }
}

private actor JamfStub {
  enum Reply: Sendable {
    case status(Int)
    case failure(URLError.Code)
  }

  private var replies: [Reply]
  private(set) var methods: [String] = []
  private(set) var paths: [String] = []

  init(replies: [Reply]) {
    self.replies = replies
  }

  func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
    let url = try #require(request.url)
    if url.path == "/api/oauth/token" {
      return try (Data(#"{"access_token":"test-token","expires_in":3600}"#.utf8), response(url, status: 200))
    }
    methods.append(request.httpMethod ?? "GET")
    paths.append(url.path)
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    if request.httpMethod == "GET" {
      #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }
    let reply = try #require(replies.first)
    replies.removeFirst()
    switch reply {
    case let .status(status): return try (Data(), response(url, status: status))
    case let .failure(code): throw URLError(code)
    }
  }

  private func response(_ url: URL, status: Int) throws -> HTTPURLResponse {
    try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
  }
}
