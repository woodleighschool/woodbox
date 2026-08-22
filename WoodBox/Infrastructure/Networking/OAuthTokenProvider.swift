import Foundation

actor OAuthTokenProvider {
  // MARK: - Properties

  private let tokenURL: URL
  private let requestBody: String

  private var accessToken: String?
  private var expiryTime: Date?
  private var activeTask: Task<String, Error>?

  // MARK: - Init

  init(tokenURL: URL, requestBody: String) {
    self.tokenURL = tokenURL
    self.requestBody = requestBody
  }

  // MARK: - Public API

  func token() async throws -> String {
    if let currentToken = accessToken, let expiry = expiryTime, Date() < expiry {
      return currentToken
    }

    if let existingTask = activeTask {
      return try await existingTask.value
    }

    let task = Task {
      try await refreshToken()
    }
    activeTask = task

    do {
      let newToken = try await task.value
      activeTask = nil
      return newToken
    } catch {
      activeTask = nil
      throw error
    }
  }

  // MARK: - Private

  private func refreshToken() async throws -> String {
    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"
    request.httpBody = requestBody.data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200 ... 299).contains(httpResponse.statusCode)
    else {
      throw URLError(.badServerResponse)
    }

    let tokenResponse = try JSONDecoder().decode(OAuthResponse.self, from: data)

    accessToken = tokenResponse.accessToken
    expiryTime = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))

    return tokenResponse.accessToken
  }

  // MARK: - Types

  private struct OAuthResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case expiresIn = "expires_in"
    }
  }
}
