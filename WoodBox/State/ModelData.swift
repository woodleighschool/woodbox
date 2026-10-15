import SwiftData
import SwiftUI

@Observable
@MainActor
final class ModelData {
  // MARK: - Scene + navigation

  var selectedTab: AppTab = .repairIntake

  // MARK: - Domain state

  let settings: AppSettings
  let assetStore: AssetStore
  let deviceSelection = DeviceSelectionState()
  let deduplication: DeduplicationState
  let snipeReferenceData: SnipeITReferenceData
  let snipeRefreshFailures = RefreshFailurePolicy()
  let deduplicationRefreshFailures = RefreshFailurePolicy()

  // MARK: - Init

  init(modelContext: ModelContext, settings: AppSettings = .shared) {
    self.settings = settings
    assetStore = AssetStore(modelContext: modelContext, fetchSnapshot: { try await AssetStore.Snapshot.fetch(settings: settings) })
    deduplication = DeduplicationState(
      fetchRecords: { try await MDMInventoryService(settings: settings).fetch() },
      deleteRecord: { try await MDMDeletionService.delete($0, settings: settings) }
    )
    snipeReferenceData = SnipeITReferenceData(settings: settings)
  }
}

// MARK: - Support types

@Observable
@MainActor
final class DeviceSelectionState {
  var query: String = ""
  var selectedDevice: Device?

  func select(_ device: Device) {
    selectedDevice = device
    query = ""
  }

  func clear() {
    selectedDevice = nil
    query = ""
  }
}
