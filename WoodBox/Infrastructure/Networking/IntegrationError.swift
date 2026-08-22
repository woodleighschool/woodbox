import Foundation

struct IntegrationError: LocalizedError {
  // MARK: - Properties

  let action: String
  let integration: String
  let statusCode: Int?
  let message: String?

  init(action: String, integration: String, statusCode: Int? = nil, message: String? = nil) {
    self.action = action
    self.integration = integration
    self.statusCode = statusCode
    self.message = message
  }

  // MARK: - LocalizedError

  var errorDescription: String? {
    if let statusCode {
      return
        "Failed to \(action) via \(integration): \(Self.statusLabel(for: statusCode)) (\(statusCode))"
    } else if let message {
      return "Failed to \(action) via \(integration): \(message)"
    }
    return "Failed to \(action) via \(integration)"
  }

  // MARK: - Private Helpers

  private static func statusLabel(for code: Int) -> String {
    switch code {
    case 400: return "Client Error (Bad Request)"
    case 401: return "Authentication Failed"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 429: return "Rate Limited"
    case 500: return "Server Error"
    default:
      let text = HTTPURLResponse.localizedString(forStatusCode: code)
      return text.isEmpty ? "HTTP \(code)" : text.capitalized
    }
  }
}
