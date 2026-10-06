import SwiftData
import SwiftUI

// MARK: - Types

private enum ConnectionTestResult: Equatable {
  case success
  case failure(String)
}

private enum SettingsSection: CaseIterable, Identifiable {
  case snipeIt
  case jamf
  case intune
  case freshservice
  case compnow

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .snipeIt: "Snipe-IT"
    case .jamf: "Jamf"
    case .intune: "Intune"
    case .freshservice: "Freshservice"
    case .compnow: "Compnow"
    }
  }

  var systemImage: String {
    switch self {
    case .snipeIt: "server.rack"
    case .jamf: "laptopcomputer"
    case .intune: "window.ceiling"
    case .freshservice: "person.crop.circle.badge.questionmark"
    case .compnow: "shippingbox"
    }
  }
}

// MARK: - SettingsView

struct SettingsView: View {
  // MARK: - Properties

  @Environment(ModelData.self) private var modelData

  // MARK: - Body

  var body: some View {
    #if os(macOS)
      TabView {
        Tab(
          SettingsSection.snipeIt.title,
          systemImage: SettingsSection.snipeIt.systemImage
        ) {
          settingsDestination(.snipeIt)
        }

        Tab(SettingsSection.jamf.title, systemImage: SettingsSection.jamf.systemImage) {
          settingsDestination(.jamf)
        }

        Tab(SettingsSection.intune.title, systemImage: SettingsSection.intune.systemImage) {
          settingsDestination(.intune)
        }

        Tab(
          SettingsSection.freshservice.title,
          systemImage: SettingsSection.freshservice.systemImage
        ) {
          settingsDestination(.freshservice)
        }

        Tab(SettingsSection.compnow.title, systemImage: SettingsSection.compnow.systemImage) {
          settingsDestination(.compnow)
        }
      }
      .frame(minWidth: 500, minHeight: 400)
      .scenePadding()
    #else
      List(SettingsSection.allCases) { section in
        NavigationLink {
          settingsDestination(section)
            .navigationTitle(section.title)
        } label: {
          Label(section.title, systemImage: section.systemImage)
        }
      }
      .navigationTitle("Settings")
    #endif
  }

  @ViewBuilder
  private func settingsDestination(_ section: SettingsSection) -> some View {
    switch section {
    case .snipeIt:
      SnipeItSettingsView(settings: modelData.settings, cacheManager: modelData.cacheManager)
    case .jamf:
      JamfSettingsView(settings: modelData.settings, cacheManager: modelData.cacheManager)
    case .intune:
      IntuneSettingsView(settings: modelData.settings, cacheManager: modelData.cacheManager)
    case .freshservice:
      FreshserviceSettingsView(settings: modelData.settings)
    case .compnow:
      CompnowSettingsView(settings: modelData.settings)
    }
  }
}

// MARK: - Subviews

struct SnipeItSettingsView: View {
  // MARK: - Properties

  @Query(sort: [SortDescriptor(\SnipeItStatus.name)])
  private var statuses: [SnipeItStatus]

  @Bindable var settings: AppSettings
  let cacheManager: CacheManager

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        EnabledToggle(
          isOn: $settings.snipeItIsEnabled,
          isConfigured: settings.configuredSnipeItClient != nil
        )
        .onChange(of: settings.snipeItIsEnabled) { _, isOn in
          Task {
            if isOn {
              await cacheManager.sync()
            } else {
              settings.jamfIsEnabled = false
              settings.intuneIsEnabled = false
              await cacheManager.purgeAllDeviceData()
            }
          }
        }

        TextField("Base URL", text: $settings.snipeItBaseURL)
        #if os(iOS)
          .keyboardType(.URL)
        #endif
        SecureField("API Key", text: $settings.snipeItAPIKey)

        ConnectionTestRow(test: settings.configuredSnipeItClient?.testSnipeItConnection)
      }

      Section("Configuration") {
        TextField("Spare Device Name Regex", text: $settings.snipeItSpareDeviceNameRegex)
        TextField("Condition Custom Field", text: $settings.snipeItConditionField)
        TextField("Condition Notes Custom Field", text: $settings.snipeItConditionNotesField)
      }

      Section("Snipe-IT Statuses") {
        if statuses.isEmpty {
          Text("Refresh the cache to fetch status labels.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        } else {
          ForEach(statuses) { status in
            LabeledContent(status.name, value: String(status.snipeItId))
          }
        }

        Button("Refresh Statuses", systemImage: "arrow.clockwise") {
          Task { await cacheManager.sync() }
        }
        .disabled(settings.snipeItIsEnabled == false || cacheManager.isSyncing)
      }
    }
    .formStyle(.grouped)
    .verbatimEntry()
    .scrollDismissesKeyboard(.interactively)
  }
}

struct JamfSettingsView: View {
  // MARK: - Properties

  @Bindable var settings: AppSettings
  let cacheManager: CacheManager

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        EnabledToggle(
          isOn: $settings.jamfIsEnabled,
          isConfigured: settings.configuredJamfClient != nil
        )
        .disabled(settings.snipeItIsEnabled == false)
        .onChange(of: settings.jamfIsEnabled) { _, isOn in
          Task {
            if isOn {
              await cacheManager.sync()
            } else {
              await cacheManager.removeMDMRecords(for: [.jamf])
            }
          }
        }

        TextField("Base URL", text: $settings.jamfBaseURL)
        #if os(iOS)
          .keyboardType(.URL)
        #endif
        TextField("Client ID", text: $settings.jamfClientId)
        SecureField("Client Secret", text: $settings.jamfClientSecret)

        ConnectionTestRow(test: settings.configuredJamfClient?.testJamfConnection)

        if settings.snipeItIsEnabled == false {
          Text("Enable Snipe-IT first; Jamf only augments cached Snipe-IT devices.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .verbatimEntry()
    .scrollDismissesKeyboard(.interactively)
  }
}

struct IntuneSettingsView: View {
  // MARK: - Properties

  @Bindable var settings: AppSettings
  let cacheManager: CacheManager

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        EnabledToggle(
          isOn: $settings.intuneIsEnabled,
          isConfigured: settings.configuredIntuneClient != nil
        )
        .disabled(settings.snipeItIsEnabled == false)
        .onChange(of: settings.intuneIsEnabled) { _, isOn in
          Task {
            if isOn {
              await cacheManager.sync()
            } else {
              await cacheManager.removeMDMRecords(for: [.intune])
            }
          }
        }

        TextField("Tenant ID", text: $settings.intuneTenantId)
        TextField("Client ID", text: $settings.intuneClientId)
        SecureField("Client Secret", text: $settings.intuneClientSecret)

        ConnectionTestRow(test: settings.configuredIntuneClient?.testIntuneConnection)

        if settings.snipeItIsEnabled == false {
          Text("Enable Snipe-IT first; Intune only augments cached Snipe-IT devices.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .verbatimEntry()
    .scrollDismissesKeyboard(.interactively)
  }
}

struct FreshserviceSettingsView: View {
  // MARK: - Properties

  @Bindable var settings: AppSettings

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        EnabledToggle(
          isOn: $settings.freshserviceIsEnabled,
          isConfigured: settings.configuredFreshserviceClient != nil
        )
        TextField("Base URL", text: $settings.freshserviceBaseURL)
        #if os(iOS)
          .keyboardType(.URL)
        #endif
        SecureField("API Key", text: $settings.freshserviceAPIKey)

        ConnectionTestRow(test: settings.configuredFreshserviceClient?.testFreshserviceConnection)
      }

      Section("Configuration") {
        TextField(
          "Workspace ID",
          value: $settings.freshserviceWorkspaceId,
          format: .number.grouping(.never)
        )
        #if os(iOS)
        .keyboardType(.numberPad)
        #endif
        TextField("Spare Custom Field", text: $settings.freshserviceSpareField)
        TextField("Compnow Ticket Custom Field", text: $settings.freshserviceCompnowField)
      }
    }
    .formStyle(.grouped)
    .verbatimEntry()
    .scrollDismissesKeyboard(.interactively)
  }
}

struct CompnowSettingsView: View {
  // MARK: - Properties

  @Bindable var settings: AppSettings

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        EnabledToggle(
          isOn: $settings.compnowIsEnabled,
          isConfigured: settings.configuredCompnowClient != nil
        )
        TextField("Username", text: $settings.compnowUsername)
        SecureField("Password", text: $settings.compnowPassword)
        SecureField("API Key", text: $settings.compnowAPIKey)

        ConnectionTestRow(test: settings.configuredCompnowClient?.testCompnowConnection)
      }
      .verbatimEntry()

      Section("End User Details") {
        TextField("Address", text: $settings.compnowAddress)
        TextField("Suburb", text: $settings.compnowSuburb)
        TextField("State", text: $settings.compnowState)
        TextField("Postcode", text: $settings.compnowPostcode)
        #if os(iOS)
          .keyboardType(.numberPad)
        #endif
        TextField("Email", text: $settings.compnowEmail)
          .verbatimEntry()
        #if os(iOS)
          .keyboardType(.emailAddress)
        #endif
        TextField("Phone", text: $settings.compnowPhone)
        #if os(iOS)
          .keyboardType(.phonePad)
        #endif
      }
    }
    .formStyle(.grouped)
    .scrollDismissesKeyboard(.interactively)
  }
}

// MARK: - EnabledToggle

/// An integration's switch. It turns on only once the integration is configured, and always turns off.
private struct EnabledToggle: View {
  @Binding var isOn: Bool
  let isConfigured: Bool

  var body: some View {
    Toggle("Enabled", isOn: $isOn)
      .disabled(!isOn && !isConfigured)
  }
}

// MARK: - ConnectionTestRow

private struct ConnectionTestRow: View {
  // MARK: - Properties

  /// The integration's connection test, or nil while it is not configured.
  let test: (@MainActor () async throws -> Void)?

  @State private var isTesting = false
  @State private var testResult: ConnectionTestResult?
  @State private var showErrorPopover = false

  // MARK: - Body

  var body: some View {
    HStack {
      Button("Test Connection") { Task { await runTest() } }
        .disabled(isTesting || test == nil)

      if isTesting {
        ProgressView().controlSize(.small)
      }

      switch testResult {
      case .success:
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .accessibilityLabel("Connection successful")
      case .failure:
        Button("Show Connection Error", systemImage: "xmark.circle.fill") {
          showErrorPopover = true
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(.red)
        .buttonStyle(.plain)
        .popover(isPresented: $showErrorPopover) {
          if case let .failure(message) = testResult {
            Text(message)
              .padding()
              .presentationCompactAdaptation(.popover)
          }
        }
      case .none:
        EmptyView()
      }
    }
  }

  // MARK: - Private Helpers

  @MainActor
  private func runTest() async {
    guard let test else { return }
    isTesting = true
    testResult = nil
    showErrorPopover = false
    defer { isTesting = false }
    do {
      try await test()
      testResult = .success
    } catch {
      testResult = .failure(error.localizedDescription)
    }
  }
}

// MARK: - Text Entry

private extension View {
  /// URLs, identifiers, and secrets are entered exactly as typed.
  func verbatimEntry() -> some View {
    autocorrectionDisabled()
    #if os(iOS)
      .textInputAutocapitalization(.never)
    #endif
  }
}
