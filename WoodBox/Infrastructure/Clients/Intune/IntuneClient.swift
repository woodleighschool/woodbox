import Foundation

struct IntuneClient {
  // MARK: - Types

  private static let graphBaseURL = URL(string: "https://graph.microsoft.com/v1.0")!

  // MARK: - Properties

  private let tokenProvider: OAuthTokenProvider
  private let http = HTTPClient.shared

  // MARK: - Init

  init(tenantId: String, clientId: String, clientSecret: String) {
    let tokenURL = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!

    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "client_secret", value: clientSecret),
      URLQueryItem(name: "scope", value: "https://graph.microsoft.com/.default"),
      URLQueryItem(name: "grant_type", value: "client_credentials"),
    ]
    let body = components.percentEncodedQuery ?? ""

    tokenProvider = OAuthTokenProvider(tokenURL: tokenURL, requestBody: body)
  }

  // MARK: - Public Methods

  func testIntuneConnection() async throws {
    _ = try await fetchIntuneDevicesPage(pageSize: 1)
  }

  func fetchIntuneDevices() async throws -> [IntuneDevice] {
    var allDevices: [IntuneDevice] = []
    var nextLink: String?

    repeat {
      let page = try await fetchIntuneDevicesPage(pageSize: 500, nextLink: nextLink)
      allDevices.append(contentsOf: page.value)
      nextLink = page.nextLink
    } while nextLink != nil

    return allDevices
  }

  func deleteIntuneDevice(id: String) async throws {
    let url = Self.graphBaseURL.appending(path: "deviceManagement/managedDevices/\(id)")
    let request = try await authorizedRequest(url: url, method: "DELETE")
    _ = try await http.data(for: request, action: "delete device", integration: "Intune")
  }

  // MARK: - Private Helpers

  private func fetchIntuneDevicesPage(
    pageSize: Int = 100,
    nextLink: String? = nil
  ) async throws -> IntuneDevicePageResponse {
    let url: URL
    if let nextLink {
      guard let linkURL = URL(string: nextLink) else {
        throw URLError(.badURL)
      }
      url = linkURL
    } else {
      url = Self.graphBaseURL.appending(
        path: "deviceManagement/managedDevices",
        queryItems: [
          URLQueryItem(name: "$top", value: "\(pageSize)"),
        ]
      )
    }

    let request = try await authorizedRequest(url: url)
    return try await http.decode(
      IntuneDevicePageResponse.self,
      from: request,
      action: "fetch devices",
      integration: "Intune"
    )
  }

  private func authorizedRequest(url: URL, method: String = "GET") async throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method

    let token = try await tokenProvider.token()
    request.setBearerToken(token)

    return request
  }
}
