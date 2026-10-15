import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppSettings {
  // MARK: - Properties

  static let shared = AppSettings()

  private let defaults: UserDefaults
  private let usesKeychain: Bool

  // MARK: - Snipe-IT

  var snipeItIsEnabled: Bool {
    didSet {
      defaults.set(snipeItIsEnabled, forKey: "snipeItIsEnabled")
    }
  }

  var snipeItBaseURL: String {
    didSet {
      defaults.set(snipeItBaseURL, forKey: "snipeItBaseURL")
    }
  }

  var snipeItAPIKey: String {
    didSet {
      guard usesKeychain else { return }
      KeychainHelper.shared.save(snipeItAPIKey, key: "snipeItAPIKey")
    }
  }

  var snipeItSpareDeviceNameRegex: String {
    didSet {
      defaults.set(
        snipeItSpareDeviceNameRegex, forKey: "snipeItSpareDeviceNameRegex"
      )
    }
  }

  var snipeItConditionField: String {
    didSet {
      defaults.set(snipeItConditionField, forKey: "snipeItConditionField")
    }
  }

  var snipeItConditionNotesField: String {
    didSet {
      defaults.set(snipeItConditionNotesField, forKey: "snipeItConditionNotesField")
    }
  }

  // MARK: - Jamf

  var jamfIsEnabled: Bool {
    didSet {
      defaults.set(jamfIsEnabled, forKey: "jamfIsEnabled")
    }
  }

  var jamfBaseURL: String {
    didSet {
      defaults.set(jamfBaseURL, forKey: "jamfBaseURL")
    }
  }

  var jamfClientId: String {
    didSet {
      defaults.set(jamfClientId, forKey: "jamfClientId")
    }
  }

  var jamfClientSecret: String {
    didSet {
      guard usesKeychain else { return }
      KeychainHelper.shared.save(jamfClientSecret, key: "jamfClientSecret")
    }
  }

  // MARK: - Intune

  var intuneIsEnabled: Bool {
    didSet {
      defaults.set(intuneIsEnabled, forKey: "intuneIsEnabled")
    }
  }

  var intuneTenantId: String {
    didSet {
      defaults.set(intuneTenantId, forKey: "intuneTenantId")
    }
  }

  var intuneClientId: String {
    didSet {
      defaults.set(intuneClientId, forKey: "intuneClientId")
    }
  }

  var intuneClientSecret: String {
    didSet {
      guard usesKeychain else { return }
      KeychainHelper.shared.save(intuneClientSecret, key: "intuneClientSecret")
    }
  }

  // MARK: - Freshservice

  var freshserviceIsEnabled: Bool {
    didSet {
      defaults.set(freshserviceIsEnabled, forKey: "freshserviceIsEnabled")
    }
  }

  var freshserviceBaseURL: String {
    didSet {
      defaults.set(freshserviceBaseURL, forKey: "freshserviceBaseURL")
    }
  }

  var freshserviceAPIKey: String {
    didSet {
      guard usesKeychain else { return }
      KeychainHelper.shared.save(freshserviceAPIKey, key: "freshserviceAPIKey")
    }
  }

  var freshserviceWorkspaceId: Int? {
    didSet {
      defaults.set(freshserviceWorkspaceId, forKey: "freshserviceWorkspaceId")
    }
  }

  var freshserviceSpareField: String {
    didSet {
      defaults.set(freshserviceSpareField, forKey: "freshserviceSpareField")
    }
  }

  var freshserviceCompnowField: String {
    didSet {
      defaults.set(freshserviceCompnowField, forKey: "freshserviceCompnowField")
    }
  }

  // MARK: - Compnow

  var compnowIsEnabled: Bool {
    didSet {
      defaults.set(compnowIsEnabled, forKey: "compnowIsEnabled")
    }
  }

  var compnowUsername: String {
    didSet {
      defaults.set(compnowUsername, forKey: "compnowUsername")
    }
  }

  var compnowPassword: String {
    didSet {
      guard usesKeychain else { return }
      KeychainHelper.shared.save(compnowPassword, key: "compnowPassword")
    }
  }

  var compnowAPIKey: String {
    didSet {
      guard usesKeychain else { return }
      KeychainHelper.shared.save(compnowAPIKey, key: "compnowAPIKey")
    }
  }

  // MARK: - Compnow Defaults

  var compnowAddress: String {
    didSet {
      defaults.set(compnowAddress, forKey: "compnowAddress")
    }
  }

  var compnowSuburb: String {
    didSet {
      defaults.set(compnowSuburb, forKey: "compnowSuburb")
    }
  }

  var compnowState: String {
    didSet {
      defaults.set(compnowState, forKey: "compnowState")
    }
  }

  var compnowPostcode: String {
    didSet {
      defaults.set(compnowPostcode, forKey: "compnowPostcode")
    }
  }

  var compnowEmail: String {
    didSet {
      defaults.set(compnowEmail, forKey: "compnowEmail")
    }
  }

  var compnowPhone: String {
    didSet {
      defaults.set(compnowPhone, forKey: "compnowPhone")
    }
  }

  // MARK: - Init

  init(defaults: UserDefaults = .standard, usesKeychain: Bool = true) {
    self.defaults = defaults
    self.usesKeychain = usesKeychain
    if usesKeychain, let url = Bundle.main.url(forResource: "Defaults", withExtension: "plist"),
       let registeredDefaults = NSDictionary(contentsOf: url) as? [String: Any]
    {
      defaults.register(defaults: registeredDefaults)
    }

    let readSecret: (String) -> String = { key in
      usesKeychain ? KeychainHelper.shared.read(key: key) ?? "" : ""
    }

    snipeItIsEnabled = defaults.bool(forKey: "snipeItIsEnabled")
    snipeItBaseURL = defaults.string(forKey: "snipeItBaseURL") ?? ""
    snipeItAPIKey = readSecret("snipeItAPIKey")
    snipeItSpareDeviceNameRegex =
      defaults.string(forKey: "snipeItSpareDeviceNameRegex") ?? ""
    snipeItConditionField =
      defaults.string(forKey: "snipeItConditionField") ?? ""
    snipeItConditionNotesField =
      defaults.string(forKey: "snipeItConditionNotesField") ?? ""
    jamfIsEnabled = defaults.bool(forKey: "jamfIsEnabled")
    jamfBaseURL = defaults.string(forKey: "jamfBaseURL") ?? ""
    jamfClientId = defaults.string(forKey: "jamfClientId") ?? ""
    jamfClientSecret = readSecret("jamfClientSecret")

    intuneIsEnabled = defaults.bool(forKey: "intuneIsEnabled")
    intuneTenantId = defaults.string(forKey: "intuneTenantId") ?? ""
    intuneClientId = defaults.string(forKey: "intuneClientId") ?? ""
    intuneClientSecret = readSecret("intuneClientSecret")

    freshserviceIsEnabled = defaults.bool(forKey: "freshserviceIsEnabled")
    freshserviceBaseURL = defaults.string(forKey: "freshserviceBaseURL") ?? ""
    freshserviceAPIKey = readSecret("freshserviceAPIKey")
    freshserviceWorkspaceId = defaults.object(forKey: "freshserviceWorkspaceId") as? Int
    freshserviceSpareField = defaults.string(forKey: "freshserviceSpareField") ?? ""
    freshserviceCompnowField =
      defaults.string(forKey: "freshserviceCompnowField") ?? ""

    compnowIsEnabled = defaults.bool(forKey: "compnowIsEnabled")
    compnowUsername = defaults.string(forKey: "compnowUsername") ?? ""
    compnowPassword = readSecret("compnowPassword")
    compnowAPIKey = readSecret("compnowAPIKey")

    compnowAddress = defaults.string(forKey: "compnowAddress") ?? ""
    compnowSuburb = defaults.string(forKey: "compnowSuburb") ?? ""
    compnowState = defaults.string(forKey: "compnowState") ?? ""
    compnowPostcode = defaults.string(forKey: "compnowPostcode") ?? ""
    compnowEmail = defaults.string(forKey: "compnowEmail") ?? ""
    compnowPhone = defaults.string(forKey: "compnowPhone") ?? ""
  }
}

// MARK: - Client Helpers

extension AppSettings {
  func lastTargetStatusId(for profile: DeviceProcessingProfile) -> Int? {
    defaults.object(forKey: targetStatusKey(for: profile)) as? Int
  }

  func setLastTargetStatusId(_ statusId: Int?, for profile: DeviceProcessingProfile) {
    let key = targetStatusKey(for: profile)
    if let statusId {
      defaults.set(statusId, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }

  private func targetStatusKey(for profile: DeviceProcessingProfile) -> String {
    "lastTargetStatusId.\(profile.rawValue)"
  }

  var compnowClient: CompnowClient? {
    compnowIsEnabled ? configuredCompnowClient : nil
  }

  var freshserviceClient: FreshserviceClient? {
    freshserviceIsEnabled ? configuredFreshserviceClient : nil
  }

  var snipeItClient: SnipeITClient? {
    snipeItIsEnabled ? configuredSnipeItClient : nil
  }

  var jamfClient: JamfClient? {
    jamfIsEnabled ? configuredJamfClient : nil
  }

  var intuneClient: IntuneClient? {
    intuneIsEnabled ? configuredIntuneClient : nil
  }

  // Each configured client is the one its settings describe, whether or not the integration
  // is enabled. It is nil while a setting it needs to connect is missing.

  var configuredCompnowClient: CompnowClient? {
    guard !compnowAPIKey.isEmpty, !compnowUsername.isEmpty, !compnowPassword.isEmpty else {
      return nil
    }
    return CompnowClient(
      apiKey: compnowAPIKey,
      username: compnowUsername,
      password: compnowPassword
    )
  }

  var configuredFreshserviceClient: FreshserviceClient? {
    guard let url = URL(string: freshserviceBaseURL), !freshserviceAPIKey.isEmpty else {
      return nil
    }
    return FreshserviceClient(baseURL: url, apiKey: freshserviceAPIKey)
  }

  var configuredSnipeItClient: SnipeITClient? {
    guard let url = URL(string: snipeItBaseURL), !snipeItAPIKey.isEmpty else { return nil }
    return SnipeITClient(baseURL: url, apiToken: snipeItAPIKey)
  }

  var configuredJamfClient: JamfClient? {
    guard let url = URL(string: jamfBaseURL), !jamfClientId.isEmpty, !jamfClientSecret.isEmpty else {
      return nil
    }
    return JamfClient(baseURL: url, clientId: jamfClientId, clientSecret: jamfClientSecret)
  }

  var configuredIntuneClient: IntuneClient? {
    guard !intuneTenantId.isEmpty, !intuneClientId.isEmpty, !intuneClientSecret.isEmpty else {
      return nil
    }
    return IntuneClient(
      tenantId: intuneTenantId,
      clientId: intuneClientId,
      clientSecret: intuneClientSecret
    )
  }
}
