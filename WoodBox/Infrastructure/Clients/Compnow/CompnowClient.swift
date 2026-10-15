import Foundation

struct CompnowClient {
  // MARK: - Properties

  private static let baseURL = URL(string: "https://prod-api.compnow.com.au/request")!
  private let apiKey: String
  private let username: String
  private let password: String
  private let http: HTTPClient

  // MARK: - Init

  init(apiKey: String, username: String, password: String, http: HTTPClient = .shared) {
    self.apiKey = apiKey
    self.username = username
    self.password = password
    self.http = http
  }

  // MARK: - Public Methods

  func testCompnowConnection() async throws {
    let request = try authorizedRequest(path: "repair/ticket/all", method: "GET")
    _ = try await send(request, action: "test connection")
  }

  func createCompnowTicket(_ ticket: CompnowTicketCreateRequest) async throws -> String {
    var request = try authorizedRequest(path: "repair/ticket", method: "POST")
    request.httpBody = try JSONEncoder().encode(ticket)

    let data = try await send(request, action: "create ticket")
    let response = try http.decode(
      CompnowTicketCreateResponse.self,
      from: data,
      action: "create ticket",
      integration: "Compnow"
    )
    let ticketId = response.ticket.ticketId

    guard !ticketId.isEmpty else { throw URLError(.badServerResponse) }
    return ticketId
  }

  // MARK: - Private Helpers

  private func send(_ request: URLRequest, action: String) async throws -> Data {
    let data = try await http.data(for: request, action: action, integration: "Compnow")
    if let failure = try? JSONDecoder().decode(CompnowFailureResponse.self, from: data) {
      throw IntegrationError(
        action: action,
        integration: "Compnow",
        message: failure.messages.joined(separator: "\n")
      )
    }
    return data
  }

  private func authorizedRequest(path: String, method: String) throws -> URLRequest {
    let url = Self.baseURL.appending(path: path)

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setBasicAuth(username: username, password: password)
    request.setValue(apiKey, forHTTPHeaderField: "Cn-Api-Key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    return request
  }
}
