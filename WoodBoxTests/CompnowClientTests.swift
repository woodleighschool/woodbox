import Foundation
import Testing
@testable import WoodBox

@Suite("Compnow responses")
@MainActor
struct CompnowClientTests {
  private let ticket = CompnowTicketCreateRequest(
    product: "MacBook Air",
    serial: "SERIAL-001",
    firstName: "Test Person",
    lastName: "",
    address1: "1 Example Street",
    suburb: "Example",
    state: "VIC",
    postcode: "3000",
    email: "helpdesk@example.invalid",
    phone: "0400000000",
    stockCode: nil,
    extras: nil,
    fault: "Broken display",
    condition: nil,
    reference: nil
  )

  @Test("HTTP success carrying messages is a failure")
  func rejectsMessages() async throws {
    let client = client(responding: #"{"messages":["Invalid API Key format."]}"#)

    let testError = await #expect(throws: IntegrationError.self) {
      try await client.testCompnowConnection()
    }
    let createError = await #expect(throws: IntegrationError.self) {
      try await client.createCompnowTicket(ticket)
    }

    #expect(testError?.message == "Invalid API Key format.")
    #expect(createError?.message == "Invalid API Key format.")
  }

  @Test("a created ticket returns its ID")
  func returnsTicketId() async throws {
    let client = client(responding: #"{"message":"Ticket was created","ticket":{"ticketId":"20000000"}}"#)

    #expect(try await client.createCompnowTicket(ticket) == "20000000")
  }

  private func client(responding body: String) -> CompnowClient {
    CompnowClient(
      apiKey: "test",
      username: "test",
      password: "test",
      http: HTTPClient { request in
        (
          Data(body.utf8),
          HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
      }
    )
  }
}
