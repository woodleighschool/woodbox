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
        settingsDestination(.snipeIt)
          .tabItem {
            Label(SettingsSection.snipeIt.title, systemImage: SettingsSection.snipeIt.systemImage)
          }

        settingsDestination(.jamf)
          .tabItem {
            Label(SettingsSection.jamf.title, systemImage: SettingsSection.jamf.systemImage)
          }

        settingsDestination(.intune)
          .tabItem {
            Label(SettingsSection.intune.title, systemImage: SettingsSection.intune.systemImage)
          }

        settingsDestination(.freshservice)
          .tabItem {
            Label(
              SettingsSection.freshservice.title,
              systemImage: SettingsSection.freshservice.systemImage
            )
          }

        settingsDestination(.compnow)
          .tabItem {
            Label(SettingsSection.compnow.title, systemImage: SettingsSection.compnow.systemImage)
          }
      }
      .frame(minWidth: 500, minHeight: 400)
      .padding()
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

        TextField("Base URL", text: $settings.snipeItBaseURL)
        SecureField("API Key", text: $settings.snipeItAPIKey)

        ConnectionTestRow(disabled: settings.snipeItBaseURL.isEmpty) {
          try await testConnection()
        }
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

        Button {
          Task { await cacheManager.sync() }
        } label: {
          Label("Refresh Statuses", systemImage: "arrow.clockwise")
        }
        .disabled(settings.snipeItIsEnabled == false || cacheManager.isSyncing)
      }
    }
    .formStyle(.grouped)
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

        TextField("Base URL", text: $settings.jamfBaseURL)
        TextField("Client ID", text: $settings.jamfClientId)
        SecureField("Client Secret", text: $settings.jamfClientSecret)

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

        TextField("Tenant ID", text: $settings.intuneTenantId)
        TextField("Client ID", text: $settings.intuneClientId)
        SecureField("Client Secret", text: $settings.intuneClientSecret)

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
        TextField("Base URL", text: $settings.freshserviceBaseURL)
        SecureField("API Key", text: $settings.freshserviceAPIKey)

        ConnectionTestRow(disabled: settings.freshserviceBaseURL.isEmpty) {
          try await testConnection()
        }
      }

      Section("Configuration") {
        TextField("Workspace ID", value: $settings.freshserviceWorkspaceId, format: .number)
        TextField(
          "Return Service Item ID",
          value: $settings.freshserviceReturnedMachineServiceItemId,
          format: .number
        )
        TextField("Return Condition Field", text: $settings.freshserviceReturnConditionField)
        TextField("Return Charger Field", text: $settings.freshserviceReturnChargerField)
        TextField("Return Notes Field", text: $settings.freshserviceReturnNotesField)
        TextField("Spare Field", text: $settings.freshserviceSpareField)
        TextField("Compnow Ticket Field", text: $settings.freshserviceCompnowField)
      }
    }
    .formStyle(.grouped)
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
        TextField("Username", text: $settings.compnowUsername)
        SecureField("Password", text: $settings.compnowPassword)
        SecureField("API Key", text: $settings.compnowAPIKey)

        ConnectionTestRow {
          try await testConnection()
        }
      }

      Section("End User Details") {
        TextField("Address", text: $settings.compnowAddress)
        TextField("Suburb", text: $settings.compnowSuburb)
        TextField("State", text: $settings.compnowState)
        TextField("Postcode", text: $settings.compnowPostcode)
        TextField("Email", text: $settings.compnowEmail)
        TextField("Phone", text: $settings.compnowPhone)
      }
    }
    .formStyle(.grouped)
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
      case .failure:
        Button {
          showErrorPopover = true
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.red)
        }
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
