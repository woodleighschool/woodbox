import Foundation

struct HTTPClient {
  static let shared = HTTPClient()

  private let session = URLSession.shared

  // MARK: - Core Methods

  func data(
    for request: URLRequest,
    action: String = "perform request",
    integration: String = "HTTP"
  ) async throws -> Data {
    let (data, response) = try await session.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    guard (200 ... 299).contains(http.statusCode) else {
      throw IntegrationError(action: action, integration: integration, statusCode: http.statusCode)
    }

    return data
  }

  func decode<T: Decodable>(
    _ type: T.Type,
    from request: URLRequest,
    action: String = "perform request",
    integration: String = "HTTP"
  ) async throws -> T {
    let data = try await data(for: request, action: action, integration: integration)
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch let decodingError as DecodingError {
      throw IntegrationError(
        action: action, integration: integration, message: decodingError.localizedDescription
      )
    }
  }
}

// MARK: - URL Construction Helpers

extension URL {
  func appending(path: String, queryItems: [URLQueryItem]? = nil) -> URL {
    var url = appendingPathComponent(path)
    if let queryItems, !queryItems.isEmpty {
      url.append(queryItems: queryItems)
    }
    return url
  }
}

// MARK: - URLRequest + Auth

extension URLRequest {
  mutating func setBearerToken(_ token: String) {
    setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  }

  mutating func setBasicAuth(username: String, password: String) {
    let credentials = "\(username):\(password)"
    guard let data = credentials.data(using: .utf8) else { return }
    setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
  }
}
