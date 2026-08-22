import Foundation

struct JamfClient {
  // MARK: - Properties

  private let baseURL: URL
  private let tokenProvider: OAuthTokenProvider
  private let http = HTTPClient.shared

  // MARK: - Init

  init(baseURL: URL, clientId: String, clientSecret: String) {
    self.baseURL = baseURL

    let tokenURL = baseURL.appending(path: "api/oauth/token")

    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "client_secret", value: clientSecret),
      URLQueryItem(name: "grant_type", value: "client_credentials"),
    ]
    let body = components.percentEncodedQuery ?? ""

    tokenProvider = OAuthTokenProvider(tokenURL: tokenURL, requestBody: body)
  }

  // MARK: - Public Methods

  func testJamfConnection() async throws {
    _ = try await fetchJamfComputersPage(page: 0, pageSize: 1)
  }

  func fetchJamfComputers() async throws -> [JamfComputer] {
    var allComputers: [JamfComputer] = []
    var page = 0
    let pageSize = 500

    while true {
      let response = try await fetchJamfComputersPage(page: page, pageSize: pageSize)
      allComputers.append(contentsOf: response.results)

      if response.results.count < pageSize {
        break
      }
      page += 1
    }

    return allComputers
  }

  func fetchJamfMobileDevices() async throws -> [JamfMobileDevice] {
    var allDevices: [JamfMobileDevice] = []
    var page = 0
    let pageSize = 500

    while true {
      let response = try await fetchJamfMobileDevicesPage(page: page, pageSize: pageSize)
      allDevices.append(contentsOf: response.results)

      if response.results.count < pageSize {
        break
      }
      page += 1
    }

    return allDevices
  }

  func deleteJamfComputer(id: String) async throws {
    let url = baseURL.appending(path: "api/v3/computers-inventory/\(id)")
    let request = try await authorizedRequest(url: url, method: "DELETE")
    _ = try await http.data(for: request, action: "delete computer", integration: "Jamf")
  }

  func deleteJamfMobileDevice(id: String) async throws {
    let url = baseURL.appending(path: "JSSResource/mobiledevices/id/\(id)")
    let request = try await authorizedRequest(url: url, method: "DELETE")
    _ = try await http.data(for: request, action: "delete mobile device", integration: "Jamf")
  }

  // MARK: - Private Helpers

  private func fetchJamfComputersPage(page: Int, pageSize: Int) async throws
    -> JamfComputersResponse
  {
    let url = baseURL.appending(
      path: "api/v3/computers-inventory",
      queryItems: [
        URLQueryItem(name: "section", value: "GENERAL"),
        URLQueryItem(name: "section", value: "HARDWARE"),
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "page-size", value: "\(pageSize)"),
        URLQueryItem(name: "sort", value: "general.name:asc"),
      ]
    )

    let request = try await authorizedRequest(url: url)
    return try await http.decode(
      JamfComputersResponse.self,
      from: request,
      action: "fetch computers",
      integration: "Jamf"
    )
  }

  private func fetchJamfMobileDevicesPage(
    page: Int,
    pageSize: Int
  ) async throws -> JamfMobileDevicesResponse {
    let url = baseURL.appending(
      path: "api/v2/mobile-devices/detail",
      queryItems: [
        URLQueryItem(name: "section", value: "GENERAL"),
        URLQueryItem(name: "section", value: "HARDWARE"),
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "page-size", value: "\(pageSize)"),
        URLQueryItem(name: "sort", value: "displayName:asc"),
      ]
    )

    let request = try await authorizedRequest(url: url)
    return try await http.decode(
      JamfMobileDevicesResponse.self,
      from: request,
      action: "fetch mobile devices",
      integration: "Jamf"
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
