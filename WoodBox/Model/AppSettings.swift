import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppSettings {
  // MARK: - Properties

  static let shared = AppSettings()

  // MARK: - Snipe-IT

  var snipeItIsEnabled: Bool {
    didSet {
      UserDefaults.standard.set(snipeItIsEnabled, forKey: "snipeItIsEnabled")
    }
  }

  var snipeItBaseURL: String {
    didSet {
      UserDefaults.standard.set(snipeItBaseURL, forKey: "snipeItBaseURL")
    }
  }

  var snipeItAPIKey: String {
    didSet {
      KeychainHelper.shared.save(snipeItAPIKey, key: "snipeItAPIKey")
    }
  }

  var snipeItSpareDeviceNameRegex: String {
    didSet {
      UserDefaults.standard.set(
        snipeItSpareDeviceNameRegex, forKey: "snipeItSpareDeviceNameRegex"
      )
    }
  }

  var snipeItConditionField: String {
    didSet {
      UserDefaults.standard.set(snipeItConditionField, forKey: "snipeItConditionField")
    }
  }

  var snipeItConditionNotesField: String {
    didSet {
      UserDefaults.standard.set(snipeItConditionNotesField, forKey: "snipeItConditionNotesField")
    }
  }

  // MARK: - Jamf

  var jamfIsEnabled: Bool {
    didSet {
      UserDefaults.standard.set(jamfIsEnabled, forKey: "jamfIsEnabled")
    }
  }

  var jamfBaseURL: String {
    didSet {
      UserDefaults.standard.set(jamfBaseURL, forKey: "jamfBaseURL")
    }
  }

  var jamfClientId: String {
    didSet {
      UserDefaults.standard.set(jamfClientId, forKey: "jamfClientId")
    }
  }

  var jamfClientSecret: String {
    didSet {
      KeychainHelper.shared.save(jamfClientSecret, key: "jamfClientSecret")
    }
  }

  // MARK: - Intune

  var intuneIsEnabled: Bool {
    didSet {
      UserDefaults.standard.set(intuneIsEnabled, forKey: "intuneIsEnabled")
    }
  }

  var intuneTenantId: String {
    didSet {
      UserDefaults.standard.set(intuneTenantId, forKey: "intuneTenantId")
    }
  }

  var intuneClientId: String {
    didSet {
      UserDefaults.standard.set(intuneClientId, forKey: "intuneClientId")
    }
  }

  var intuneClientSecret: String {
    didSet {
      KeychainHelper.shared.save(intuneClientSecret, key: "intuneClientSecret")
    }
  }

  // MARK: - Freshservice

  var freshserviceIsEnabled: Bool {
    didSet {
      UserDefaults.standard.set(freshserviceIsEnabled, forKey: "freshserviceIsEnabled")
    }
  }

  var freshserviceBaseURL: String {
    didSet {
      UserDefaults.standard.set(freshserviceBaseURL, forKey: "freshserviceBaseURL")
    }
  }

  var freshserviceAPIKey: String {
    didSet {
      KeychainHelper.shared.save(freshserviceAPIKey, key: "freshserviceAPIKey")
    }
  }

  var freshserviceWorkspaceId: Int {
    didSet {
      UserDefaults.standard.set(freshserviceWorkspaceId, forKey: "freshserviceWorkspaceId")
    }
  }

  var freshserviceSpareField: String {
    didSet {
      UserDefaults.standard.set(freshserviceSpareField, forKey: "freshserviceSpareField")
    }
  }

  var freshserviceCompnowField: String {
    didSet {
      UserDefaults.standard.set(freshserviceCompnowField, forKey: "freshserviceCompnowField")
    }
  }

  // MARK: - Compnow

  var compnowIsEnabled: Bool {
    didSet {
      UserDefaults.standard.set(compnowIsEnabled, forKey: "compnowIsEnabled")
    }
  }

  var compnowUsername: String {
    didSet {
      UserDefaults.standard.set(compnowUsername, forKey: "compnowUsername")
    }
  }

  var compnowPassword: String {
    didSet {
      KeychainHelper.shared.save(compnowPassword, key: "compnowPassword")
    }
  }

  var compnowAPIKey: String {
    didSet {
      KeychainHelper.shared.save(compnowAPIKey, key: "compnowAPIKey")
    }
  }

  // MARK: - Compnow Defaults

  var compnowAddress: String {
    didSet {
      UserDefaults.standard.set(compnowAddress, forKey: "compnowAddress")
    }
  }

  var compnowSuburb: String {
    didSet {
      UserDefaults.standard.set(compnowSuburb, forKey: "compnowSuburb")
    }
  }

  var compnowState: String {
    didSet {
      UserDefaults.standard.set(compnowState, forKey: "compnowState")
    }
  }

  var compnowPostcode: String {
    didSet {
      UserDefaults.standard.set(compnowPostcode, forKey: "compnowPostcode")
    }
  }

  var compnowEmail: String {
    didSet {
      UserDefaults.standard.set(compnowEmail, forKey: "compnowEmail")
    }
  }

  var compnowPhone: String {
    didSet {
      UserDefaults.standard.set(compnowPhone, forKey: "compnowPhone")
    }
  }

  // MARK: - Init

  private init() {
    if let url = Bundle.main.url(forResource: "Defaults", withExtension: "plist"),
       let defaults = NSDictionary(contentsOf: url) as? [String: Any]
    {
      UserDefaults.standard.register(defaults: defaults)
    }

    let keychain = KeychainHelper.shared

    snipeItIsEnabled = UserDefaults.standard.bool(forKey: "snipeItIsEnabled")
    snipeItBaseURL = UserDefaults.standard.string(forKey: "snipeItBaseURL") ?? ""
    snipeItAPIKey = keychain.read(key: "snipeItAPIKey") ?? ""
    snipeItSpareDeviceNameRegex =
      UserDefaults.standard.string(forKey: "snipeItSpareDeviceNameRegex") ?? ""
    snipeItConditionField =
      UserDefaults.standard.string(forKey: "snipeItConditionField") ?? ""
    snipeItConditionNotesField =
      UserDefaults.standard.string(forKey: "snipeItConditionNotesField") ?? ""
    jamfIsEnabled = UserDefaults.standard.bool(forKey: "jamfIsEnabled")
    jamfBaseURL = UserDefaults.standard.string(forKey: "jamfBaseURL") ?? ""
    jamfClientId = UserDefaults.standard.string(forKey: "jamfClientId") ?? ""
    jamfClientSecret = keychain.read(key: "jamfClientSecret") ?? ""

    intuneIsEnabled = UserDefaults.standard.bool(forKey: "intuneIsEnabled")
    intuneTenantId = UserDefaults.standard.string(forKey: "intuneTenantId") ?? ""
    intuneClientId = UserDefaults.standard.string(forKey: "intuneClientId") ?? ""
    intuneClientSecret = keychain.read(key: "intuneClientSecret") ?? ""

    freshserviceIsEnabled = UserDefaults.standard.bool(forKey: "freshserviceIsEnabled")
    freshserviceBaseURL = UserDefaults.standard.string(forKey: "freshserviceBaseURL") ?? ""
    freshserviceAPIKey = keychain.read(key: "freshserviceAPIKey") ?? ""
    freshserviceWorkspaceId = UserDefaults.standard.integer(forKey: "freshserviceWorkspaceId")
    freshserviceSpareField = UserDefaults.standard.string(forKey: "freshserviceSpareField") ?? ""
    freshserviceCompnowField =
      UserDefaults.standard.string(forKey: "freshserviceCompnowField") ?? ""

    compnowIsEnabled = UserDefaults.standard.bool(forKey: "compnowIsEnabled")
    compnowUsername = UserDefaults.standard.string(forKey: "compnowUsername") ?? ""
    compnowPassword = keychain.read(key: "compnowPassword") ?? ""
    compnowAPIKey = keychain.read(key: "compnowAPIKey") ?? ""

    compnowAddress = UserDefaults.standard.string(forKey: "compnowAddress") ?? ""
    compnowSuburb = UserDefaults.standard.string(forKey: "compnowSuburb") ?? ""
    compnowState = UserDefaults.standard.string(forKey: "compnowState") ?? ""
    compnowPostcode = UserDefaults.standard.string(forKey: "compnowPostcode") ?? ""
    compnowEmail = UserDefaults.standard.string(forKey: "compnowEmail") ?? ""
    compnowPhone = UserDefaults.standard.string(forKey: "compnowPhone") ?? ""
  }
}

// MARK: - Client Helpers

extension AppSettings {
  func lastTargetStatusId(for profile: DeviceProcessingProfile) -> Int? {
    UserDefaults.standard.object(forKey: targetStatusKey(for: profile)) as? Int
  }

  func setLastTargetStatusId(_ statusId: Int?, for profile: DeviceProcessingProfile) {
    let key = targetStatusKey(for: profile)
    if let statusId {
      UserDefaults.standard.set(statusId, forKey: key)
    } else {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }

  private func targetStatusKey(for profile: DeviceProcessingProfile) -> String {
    "lastTargetStatusId.\(profile.rawValue)"
  }

  var compnowClient: CompnowClient? {
    guard compnowIsEnabled else { return nil }
    return CompnowClient(
      apiKey: compnowAPIKey,
      username: compnowUsername,
      password: compnowPassword
    )
  }

  var freshserviceClient: FreshserviceClient? {
    guard freshserviceIsEnabled, let url = URL(string: freshserviceBaseURL) else { return nil }
    return FreshserviceClient(baseURL: url, apiKey: freshserviceAPIKey)
  }

  var snipeItClient: SnipeITClient? {
    guard snipeItIsEnabled, let url = URL(string: snipeItBaseURL) else { return nil }
    return SnipeITClient(baseURL: url, apiToken: snipeItAPIKey)
  }

  var jamfClient: JamfClient? {
    guard jamfIsEnabled, let url = URL(string: jamfBaseURL) else { return nil }
    return JamfClient(baseURL: url, clientId: jamfClientId, clientSecret: jamfClientSecret)
  }

  var intuneClient: IntuneClient? {
    guard intuneIsEnabled else { return nil }
    return IntuneClient(
      tenantId: intuneTenantId,
      clientId: intuneClientId,
      clientSecret: intuneClientSecret
    )
  }
}
