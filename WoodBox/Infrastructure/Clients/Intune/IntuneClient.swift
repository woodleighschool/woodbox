import Foundation

struct IntuneClient {
  // MARK: - Types

  private static let graphBaseURL = URL(string: "https://graph.microsoft.com/v1.0")!

  // MARK: - Properties

  private let tokenProvider: OAuthTokenProvider
  private let http: HTTPClient

  // MARK: - Init

  init(tenantId: String, clientId: String, clientSecret: String, http: HTTPClient = .shared) {
    self.http = http
    let tokenURL = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!

    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "client_secret", value: clientSecret),
      URLQueryItem(name: "scope", value: "https://graph.microsoft.com/.default"),
      URLQueryItem(name: "grant_type", value: "client_credentials"),
    ]
    let body = components.percentEncodedQuery ?? ""

    tokenProvider = OAuthTokenProvider(tokenURL: tokenURL, requestBody: body, http: http)
  }

  // MARK: - Public Methods

  func testIntuneConnection() async throws {
    let _: IntunePage<IntuneDevice> = try await fetchPage(
      from: managedDevicesURL(pageSize: 1),
      action: "fetch devices"
    )
  }

  func fetchIntuneDevices(serial: String? = nil) async throws -> [IntuneDevice] {
    try await fetchAll(from: managedDevicesURL(pageSize: 500, serial: serial), action: "fetch devices")
  }

  func deleteIntuneDevice(id: String) async throws {
    let url = Self.graphBaseURL.appending(path: "deviceManagement/managedDevices/\(id)")
    let request = try await authorizedRequest(url: url, method: "DELETE")
    _ = try await http.data(for: request, action: "delete device", integration: "Intune")
  }

  // MARK: - Private Helpers

  private func managedDevicesURL(pageSize: Int, serial: String? = nil) -> URL {
    Self.graphBaseURL.appending(
      path: "deviceManagement/managedDevices",
      queryItems: [
        URLQueryItem(name: "$top", value: "\(pageSize)"),
        URLQueryItem(name: "$select", value: "id,deviceName,serialNumber,lastSyncDateTime,model"),
        serial.map { URLQueryItem(name: "$filter", value: "serialNumber eq '\($0.replacingOccurrences(of: "'", with: "''"))'") },
      ].compactMap(\.self)
    )
  }

  private func fetchAll<Value: Decodable>(from url: URL, action: String) async throws -> [Value] {
    var values: [Value] = []
    var nextURL: URL? = url

    while let url = nextURL {
      try Task.checkCancellation()
      let page: IntunePage<Value> = try await fetchPage(from: url, action: action)
      values.append(contentsOf: page.value)
      nextURL = try page.nextLink.map { link in
        guard let linkURL = URL(string: link) else {
          throw URLError(.badURL)
        }
        return linkURL
      }
    }

    return values
  }

  private func fetchPage<Value: Decodable>(
    from url: URL,
    action: String
  ) async throws -> IntunePage<Value> {
    let request = try await authorizedRequest(url: url)
    return try await http.decode(
      IntunePage<Value>.self,
      from: request,
      action: action,
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
