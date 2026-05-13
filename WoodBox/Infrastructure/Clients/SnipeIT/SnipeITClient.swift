//
//  SnipeITClient.swift
//  WoodBox
//
//  Created by Alexander Hyde on 8/2/2026.
//

import Foundation

struct SnipeITClient {
  // MARK: - Properties

  private let baseURL: URL
  private let apiToken: String
  private let http = HTTPClient.shared

  // MARK: - Init

  init(baseURL: URL, apiToken: String) {
    self.baseURL = baseURL
    self.apiToken = apiToken
  }

  // MARK: - Public Methods

  func testSnipeItConnection() async throws {
    _ = try await fetchSnipeItAssetsPage(limit: 1, offset: 0)
  }

  func fetchSnipeItAssets() async throws -> [SnipeItAssetResponse] {
    var allAssets: [SnipeItAssetResponse] = []
    var offset = 0
    let limit = 200

    while true {
      let page = try await fetchSnipeItAssetsPage(limit: limit, offset: offset)
      allAssets.append(contentsOf: page.rows)

      if page.rows.count < limit {
        break
      }
      offset += limit
    }

    return allAssets
  }

  func checkinSnipeItAsset(assetId: Int, request checkin: SnipeItCheckinRequest) async throws {
    let url = baseURL.appending(path: "api/v1/hardware/\(assetId)/checkin")
    var request = authorizedRequest(url: url, method: "POST")
    request.httpBody = try JSONEncoder().encode(checkin)
    _ = try await http.data(for: request, action: "check-in asset", integration: "Snipe-IT")
  }

  func updateSnipeItAsset(assetId: Int, request update: SnipeItUpdateRequest) async throws {
    let url = baseURL.appending(path: "api/v1/hardware/\(assetId)")
    var request = authorizedRequest(url: url, method: "PATCH")
    request.httpBody = try JSONEncoder().encode(update)
    _ = try await http.data(for: request, action: "patch asset", integration: "Snipe-IT")
  }

  func checkoutSnipeItAsset(assetId: Int, request checkout: SnipeItCheckoutRequest) async throws {
    let url = baseURL.appending(path: "api/v1/hardware/\(assetId)/checkout")
    var request = authorizedRequest(url: url, method: "POST")
    request.httpBody = try JSONEncoder().encode(checkout)
    _ = try await http.data(for: request, action: "checkout asset", integration: "Snipe-IT")
  }

  func fetchSnipeItUsers() async throws -> [SnipeItUserResponse] {
    var allUsers: [SnipeItUserResponse] = []
    var offset = 0
    let limit = 200

    while true {
      let page = try await fetchSnipeItUsersPage(limit: limit, offset: offset)
      allUsers.append(contentsOf: page.rows)

      if page.rows.count < limit {
        break
      }
      offset += limit
    }

    return allUsers
  }

  func fetchSnipeItStatuses() async throws -> [SnipeItStatusResponse] {
    var allStatuses: [SnipeItStatusResponse] = []
    var offset = 0
    let limit = 200

    while true {
      let page = try await fetchSnipeItStatusesPage(limit: limit, offset: offset)
      allStatuses.append(contentsOf: page.rows)

      if page.rows.count < limit {
        break
      }
      offset += limit
    }

    return allStatuses
  }

  // MARK: - Private Helpers

  private func fetchSnipeItAssetsPage(limit: Int, offset: Int) async throws -> SnipeItAssetsResponse {
    let url = baseURL.appending(
      path: "api/v1/hardware",
      queryItems: [
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "offset", value: "\(offset)"),
      ]
    )
    let request = authorizedRequest(url: url)
    return try await http.decode(
      SnipeItAssetsResponse.self,
      from: request,
      action: "fetch assets",
      integration: "Snipe-IT"
    )
  }

  private func fetchSnipeItUsersPage(limit: Int, offset: Int) async throws -> SnipeItUsersResponse {
    let url = baseURL.appending(
      path: "api/v1/users",
      queryItems: [
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "offset", value: "\(offset)"),
      ]
    )
    let request = authorizedRequest(url: url)
    return try await http.decode(
      SnipeItUsersResponse.self,
      from: request,
      action: "fetch users",
      integration: "Snipe-IT"
    )
  }

  private func fetchSnipeItStatusesPage(
    limit: Int, offset: Int
  ) async throws -> SnipeItStatusesResponse {
    let url = baseURL.appending(
      path: "api/v1/statuslabels",
      queryItems: [
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "offset", value: "\(offset)"),
      ]
    )
    let request = authorizedRequest(url: url)
    return try await http.decode(
      SnipeItStatusesResponse.self,
      from: request,
      action: "fetch statuses",
      integration: "Snipe-IT"
    )
  }

  private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setBearerToken(apiToken)
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if method != "GET" {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }
}
