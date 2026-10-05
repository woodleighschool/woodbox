import Foundation
import OSLog

struct JamfClient {
  // MARK: - Properties

  private let baseURL: URL
  private let tokenProvider: OAuthTokenProvider
  private let http: HTTPClient
  private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WoodBox", category: "Jamf")

  // MARK: - Init

  init(baseURL: URL, clientId: String, clientSecret: String, http: HTTPClient = .shared) {
    self.baseURL = baseURL
    self.http = http

    let tokenURL = baseURL.appending(path: "api/oauth/token")

    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "client_secret", value: clientSecret),
      URLQueryItem(name: "grant_type", value: "client_credentials"),
    ]
    let body = components.percentEncodedQuery ?? ""

    tokenProvider = OAuthTokenProvider(tokenURL: tokenURL, requestBody: body, http: http)
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
    try await deleteRecord(at: url, action: "delete computer")
  }

  func deleteJamfMobileDevice(id: String) async throws {
    let url = baseURL.appending(path: "JSSResource/mobiledevices/id/\(id)")
    try await deleteRecord(at: url, action: "delete mobile device")
  }

  // MARK: - Private Helpers

  private func deleteRecord(at url: URL, action: String) async throws {
    let request = try await authorizedRequest(url: url, method: "DELETE")
    let started = ContinuousClock.now
    do {
      _ = try await http.data(for: request, action: action, integration: "Jamf")
    } catch let error as IntegrationError where error.statusCode == 404 {
      return
    } catch {
      let elapsed = started.duration(to: .now)
      let code = (error as? IntegrationError)?.statusCode ?? (error as NSError).code
      Self.logger.warning("\(action, privacy: .public) failed after \(String(describing: elapsed), privacy: .public), code \(code)")
      guard Self.hasUncertainOutcome(error) else { throw error }

      // A lost response doesn't imply a failed mutation. Read back; never repeat DELETE here.
      for attempt in 0 ..< 3 {
        try Task.checkCancellation()
        if attempt > 0 {
          try await Task.sleep(for: .seconds(1))
        }
        var verification = try await authorizedRequest(url: url)
        verification.cachePolicy = .reloadIgnoringLocalCacheData
        do {
          _ = try await http.data(for: verification, action: "verify deletion", integration: "Jamf")
        } catch let verificationError as IntegrationError where verificationError.statusCode == 404 {
          Self.logger.notice("\(action, privacy: .public) confirmed absent after an uncertain response")
          return
        } catch {
          try Task.checkCancellation()
          break
        }
      }
      throw error
    }
  }

  private static func hasUncertainOutcome(_ error: any Error) -> Bool {
    if let error = error as? IntegrationError, let status = error.statusCode {
      return status == 408 || (500 ... 599).contains(status)
    }
    guard let error = error as? URLError else { return false }
    return [.timedOut, .networkConnectionLost, .badServerResponse].contains(error.code)
  }

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
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let token = try await tokenProvider.token()
    request.setBearerToken(token)

    return request
  }
}
