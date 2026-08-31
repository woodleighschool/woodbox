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
            .refreshable {
              await modelData.cacheManager.sync()
            }
        } label: {
          Label(section.title, systemImage: section.systemImage)
        }
      }
      .navigationTitle("Settings")
      .refreshable {
        await modelData.cacheManager.sync()
      }
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
        Toggle("Enabled", isOn: $settings.snipeItIsEnabled)
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

        SettingsTextField("Base URL", text: $settings.snipeItBaseURL, kind: .url)
        SettingsSecureField("API Key", text: $settings.snipeItAPIKey)

        ConnectionTestRow(disabled: settings.snipeItBaseURL.isEmpty) {
          try await testConnection()
        }
      }

      Section("Configuration") {
        SettingsTextField(
          "Spare Device Name Regex",
          text: $settings.snipeItSpareDeviceNameRegex,
          kind: .identifier
        )
        SettingsTextField(
          "Condition Custom Field",
          text: $settings.snipeItConditionField,
          kind: .identifier
        )
        SettingsTextField(
          "Condition Notes Custom Field",
          text: $settings.snipeItConditionNotesField,
          kind: .identifier
        )
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

        #if os(macOS)
          Button {
            Task { await cacheManager.sync() }
          } label: {
            Label("Refresh Statuses", systemImage: "arrow.clockwise")
          }
          .disabled(settings.snipeItIsEnabled == false || cacheManager.isSyncing)
        #endif
      }
    }
    .formStyle(.grouped)
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Private Helpers

  private func testConnection() async throws {
    guard let url = URL(string: settings.snipeItBaseURL) else { throw URLError(.badURL) }
    let client = SnipeITClient(baseURL: url, apiToken: settings.snipeItAPIKey)
    try await client.testSnipeItConnection()
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
        Toggle("Enabled", isOn: $settings.jamfIsEnabled)
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

        SettingsTextField("Base URL", text: $settings.jamfBaseURL, kind: .url)
        SettingsTextField("Client ID", text: $settings.jamfClientId, kind: .identifier)
        SettingsSecureField("Client Secret", text: $settings.jamfClientSecret)

        ConnectionTestRow(disabled: settings.jamfBaseURL.isEmpty) {
          try await testConnection()
        }

        if settings.snipeItIsEnabled == false {
          Text("Enable Snipe-IT first; Jamf only augments cached Snipe-IT devices.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Private Helpers

  private func testConnection() async throws {
    guard let url = URL(string: settings.jamfBaseURL) else { throw URLError(.badURL) }
    let client = JamfClient(
      baseURL: url,
      clientId: settings.jamfClientId,
      clientSecret: settings.jamfClientSecret
    )
    try await client.testJamfConnection()
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
        Toggle("Enabled", isOn: $settings.intuneIsEnabled)
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

        SettingsTextField("Tenant ID", text: $settings.intuneTenantId, kind: .identifier)
        SettingsTextField("Client ID", text: $settings.intuneClientId, kind: .identifier)
        SettingsSecureField("Client Secret", text: $settings.intuneClientSecret)

        ConnectionTestRow {
          try await testConnection()
        }

        if settings.snipeItIsEnabled == false {
          Text("Enable Snipe-IT first; Intune only augments cached Snipe-IT devices.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Private Helpers

  private func testConnection() async throws {
    let client = IntuneClient(
      tenantId: settings.intuneTenantId,
      clientId: settings.intuneClientId,
      clientSecret: settings.intuneClientSecret
    )
    try await client.testIntuneConnection()
  }
}

struct FreshserviceSettingsView: View {
  // MARK: - Properties

  @Bindable var settings: AppSettings

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        Toggle("Enabled", isOn: $settings.freshserviceIsEnabled)
        SettingsTextField("Base URL", text: $settings.freshserviceBaseURL, kind: .url)
        SettingsSecureField("API Key", text: $settings.freshserviceAPIKey)

        ConnectionTestRow(disabled: settings.freshserviceBaseURL.isEmpty) {
          try await testConnection()
        }
      }

      Section("Configuration") {
        SettingsIntegerField("Workspace ID", value: $settings.freshserviceWorkspaceId)
        SettingsTextField(
          "Spare Custom Field",
          text: $settings.freshserviceSpareField,
          kind: .identifier
        )
        SettingsTextField(
          "Compnow Ticket Custom Field",
          text: $settings.freshserviceCompnowField,
          kind: .identifier
        )
      }
    }
    .formStyle(.grouped)
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Private Helpers

  private func testConnection() async throws {
    guard let url = URL(string: settings.freshserviceBaseURL) else {
      throw URLError(.badURL)
    }
    let client = FreshserviceClient(baseURL: url, apiKey: settings.freshserviceAPIKey)
    try await client.testFreshserviceConnection()
  }
}

struct CompnowSettingsView: View {
  // MARK: - Properties

  @Bindable var settings: AppSettings

  // MARK: - Body

  var body: some View {
    Form {
      Section("Credentials") {
        Toggle("Enabled", isOn: $settings.compnowIsEnabled)
        SettingsTextField("Username", text: $settings.compnowUsername, kind: .identifier)
        SettingsSecureField("Password", text: $settings.compnowPassword)
        SettingsSecureField("API Key", text: $settings.compnowAPIKey)

        ConnectionTestRow {
          try await testConnection()
        }
      }

      Section("End User Details") {
        SettingsTextField("Address", text: $settings.compnowAddress)
        SettingsTextField("Suburb", text: $settings.compnowSuburb)
        SettingsTextField("State", text: $settings.compnowState)
        SettingsTextField("Postcode", text: $settings.compnowPostcode, kind: .number)
        SettingsTextField("Email", text: $settings.compnowEmail, kind: .email)
        SettingsTextField("Phone", text: $settings.compnowPhone, kind: .telephone)
      }
    }
    .formStyle(.grouped)
    .scrollDismissesKeyboard(.interactively)
  }

  // MARK: - Private Helpers

  private func testConnection() async throws {
    let client = CompnowClient(
      apiKey: settings.compnowAPIKey,
      username: settings.compnowUsername,
      password: settings.compnowPassword
    )
    try await client.testCompnowConnection()
  }
}

// MARK: - ConnectionTestRow

private struct ConnectionTestRow: View {
  // MARK: - Properties

  var disabled: Bool = false
  let action: @MainActor () async throws -> Void

  @State private var isTesting = false
  @State private var testResult: ConnectionTestResult?
  @State private var showErrorPopover = false

  // MARK: - Body

  var body: some View {
    HStack {
      Button("Test Connection") { Task { await runTest() } }
        .disabled(isTesting || disabled)

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
    isTesting = true
    testResult = nil
    showErrorPopover = false
    defer { isTesting = false }
    do {
      try await action()
      testResult = .success
    } catch {
      testResult = .failure(error.localizedDescription)
    }
  }
}

// MARK: - Settings Fields

private enum SettingsFieldKind {
  case plain
  case url
  case identifier
  case email
  case telephone
  case number
}

private struct SettingsTextField: View {
  let title: String
  @Binding var text: String
  let kind: SettingsFieldKind

  init(
    _ title: String,
    text: Binding<String>,
    kind: SettingsFieldKind = .plain
  ) {
    self.title = title
    _text = text
    self.kind = kind
  }

  var body: some View {
    LabeledContent(title) {
      configuredField
    }
  }

  @ViewBuilder
  private var configuredField: some View {
    let field = TextField(title, text: $text)
      .labelsHidden()

    switch kind {
    case .plain:
      field
    case .url:
      field
        .textContentType(.URL)
        .autocorrectionDisabled()
      #if os(iOS)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
      #endif
    case .identifier:
      field
        .autocorrectionDisabled()
      #if os(iOS)
        .textInputAutocapitalization(.never)
      #endif
    case .email:
      field
        .textContentType(.emailAddress)
        .autocorrectionDisabled()
      #if os(iOS)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
      #endif
    case .telephone:
      field
        .textContentType(.telephoneNumber)
      #if os(iOS)
        .keyboardType(.phonePad)
      #endif
    case .number:
      field
        .autocorrectionDisabled()
      #if os(iOS)
        .keyboardType(.numberPad)
      #endif
    }
  }
}

private struct SettingsSecureField: View {
  let title: String
  @Binding var text: String

  init(_ title: String, text: Binding<String>) {
    self.title = title
    _text = text
  }

  var body: some View {
    LabeledContent(title) {
      SecureField(title, text: $text)
        .labelsHidden()
        .autocorrectionDisabled()
      #if os(iOS)
        .textInputAutocapitalization(.never)
      #endif
    }
    .privacySensitive()
  }
}

private struct SettingsIntegerField: View {
  let title: String
  @Binding var value: Int

  init(_ title: String, value: Binding<Int>) {
    self.title = title
    _value = value
  }

  var body: some View {
    LabeledContent(title) {
      TextField(title, value: $value, format: .number)
        .labelsHidden()
      #if os(iOS)
        .keyboardType(.numberPad)
      #endif
    }
  }
}
