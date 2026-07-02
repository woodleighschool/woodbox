//
//  CompnowClient.swift
//  WoodBox
//
//  Created by Alexander Hyde on 8/2/2026.
//

import Foundation

struct CompnowClient {
  // MARK: - Properties

  private static let baseURL = URL(string: "https://prod-api.compnow.com.au/request")!
  private let apiKey: String
  private let username: String
  private let password: String
  private let http = HTTPClient.shared

  // MARK: - Init

  init(apiKey: String, username: String, password: String) {
    self.apiKey = apiKey
    self.username = username
    self.password = password
  }

  // MARK: - Public Methods

  func testCompnowConnection() async throws {
    let request = try authorizedRequest(path: "repair/ticket/all", method: "GET")
    _ = try await http.data(for: request, action: "test connection", integration: "Compnow")
  }

  func createCompnowTicket(_ ticket: CompnowTicketCreateRequest) async throws -> String {
    var request = try authorizedRequest(path: "repair/ticket", method: "POST")
    request.httpBody = try JSONEncoder().encode(ticket)

    let response = try await http.decode(
      CompnowTicketCreateResponse.self,
      from: request,
      action: "create ticket",
      integration: "Compnow"
    )
    let ticketId = response.ticket.ticketId

    guard !ticketId.isEmpty else { throw URLError(.badServerResponse) }
    return ticketId
  }

  // MARK: - Private Helpers

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
