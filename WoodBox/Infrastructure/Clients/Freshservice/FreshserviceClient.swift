import Foundation

struct FreshserviceClient {
  // MARK: - Properties

  private let apiKey: String
  private let baseURL: URL
  private let http = HTTPClient.shared

  // MARK: - Init

  init(baseURL: URL, apiKey: String) {
    self.baseURL = baseURL
    self.apiKey = apiKey
  }

  // MARK: - Public Methods

  func testFreshserviceConnection() async throws {
    _ = try await fetchFreshserviceTickets(limit: 1)
  }

  func createFreshserviceTicket(_ ticket: FreshserviceTicketRequest) async throws -> String {
    let url = baseURL.appending(path: "api/v2/tickets")
    var request = authorizedRequest(url: url, method: "POST")
    request.httpBody = try JSONEncoder().encode(ticket)

    let response = try await http.decode(
      FreshserviceTicketResponse.self,
      from: request,
      action: "create ticket",
      integration: "Freshservice"
    )
    return String(response.ticket.id)
  }

  // MARK: - Private Helpers

  private func fetchFreshserviceTickets(limit: Int) async throws {
    let url = baseURL.appending(
      path: "api/v2/tickets",
      queryItems: [URLQueryItem(name: "per_page", value: "\(limit)")]
    )

    let request = authorizedRequest(url: url)
    _ = try await http.data(for: request, action: "test connection", integration: "Freshservice")
  }

  private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setBasicAuth(username: apiKey, password: "X")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if method != "GET" {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }
}
